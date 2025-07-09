
using HTTP
using JSON

struct AFD
    alfabeto::Set{String}
    estados::Set{String}
    inicial::String
    finais::Set{String}
    transicoes::Dict{Tuple{String,String},String}
end

# --- Funções de Parsing e Validação ---
function ler_afd_de_string(conteudo::String)
    if isempty(strip(conteudo))
        return "Erro: O texto de entrada está vazio."
    end
    #Inicialização das variaveis 
    alfabeto = Set{String}()
    estados = Set{String}()
    inicial = ""
    finais = Set{String}()
    transicoes = Dict{Tuple{String,String},String}()
    modo_transicao = false
    definicoes_encontradas = Set{String}()

    #inicia a leitura do conteudo
    for (i, linha_bruta) in enumerate(split(conteudo, '\n'))
        #remove todas os comentarios 
        linha = strip(split(linha_bruta, '#')[1])
        if isempty(linha)
            continue
        end
        # verifição para ver se já estamos na parte das transicoes
        if startswith(linha, "transicoes")
            if modo_transicao
                return "Erro na linha $i: A seção 'transicoes' foi definida mais de uma vez."
            end
            modo_transicao = true
            push!(definicoes_encontradas, "transicoes")
            continue
        end
        
        if !modo_transicao
            # faz a verificação se os campos estão no formato CHAVE: VALOR
            partes_def = split(linha, ':', limit=2)
            if length(partes_def) != 2
                return "Erro de formato na linha $i: '$linha_bruta'. Esperava 'chave:valor'."
            end
            chave, valor = strip.(partes_def)
            if isempty(valor)
                return "Erro na linha $i: A definição para '$chave' não pode ser vazia."
            end
            # filtramos os valores e separamos por vigula
            valores_split = filter!(!isempty, strip.(split(valor, ',')))
            # Verificação de qual informação estamos lidando
            if chave == "alfabeto"
                union!(alfabeto, valores_split)
            elseif chave == "estados"
                union!(estados, valores_split)
            elseif chave == "inicial"
                inicial = valor
            elseif chave == "finais"
                union!(finais, valores_split)
            else
                return "Erro na linha $i: Chave desconhecida '$chave'."
            end
            push!(definicoes_encontradas, chave)
        else
            partes_trans = strip.(split(linha, ','))
            if length(partes_trans) != 3
                return "Erro de formato na linha $i: '$linha_bruta'. Esperava 'origem,destino,simbolo'."
            end
            transicoes[(partes_trans[1], partes_trans[3])] = partes_trans[2]
        end
    end
    #definimos quais são as secao obrigatorias que devem estar presente no texto
    secoes_obrigatorias = Set(["alfabeto", "estados", "inicial", "finais", "transicoes"])
    secoes_faltantes = setdiff(secoes_obrigatorias, definicoes_encontradas)
    #verificacao se há algum secao faltante
    if !isempty(secoes_faltantes)
        return "Erro: Faltando seções obrigatórias: $(join(collect(secoes_faltantes), ", "))."
    end
    return AFD(alfabeto, estados, inicial, finais, transicoes)
end

# Funçaõ que valida a logica do AFD
function validar_afd(afd::AFD)
    if !(afd.inicial in afd.estados)
        return "Erro de Validade: O estado inicial '$(afd.inicial)' não está no conjunto de estados."
    end
    for f in afd.finais
        if !(f in afd.estados)
            return "Erro de Validade: O estado final '$f' não está no conjunto de estados."
        end
    end
    for estado in afd.estados, simbolo in afd.alfabeto
        if !haskey(afd.transicoes, (estado, simbolo))
            return "Erro de Validade: A transição para ('$estado', '$simbolo') não está definida."
        end
    end
    return "AFD válido."
end
#REMOVE OS ESTADOS INALCANCAVEIS A PARTIR DO ESTADO INICIAL
function remover_estados_inalcancaveis(afd::AFD)
    alcancados = Set([afd.inicial])
    fila = [afd.inicial]
    while !isempty(fila)
        estado_atual = popfirst!(fila)
        for simbolo in afd.alfabeto
            proximo_estado = get(afd.transicoes, (estado_atual, simbolo), nothing)
            if proximo_estado !== nothing && !(proximo_estado in alcancados)
                push!(alcancados, proximo_estado)
                push!(fila, proximo_estado)
            end
        end
    end
    return AFD(afd.alfabeto, alcancados, afd.inicial, intersect(afd.finais, alcancados), Dict(k => v for (k, v) in afd.transicoes if k[1] in alcancados))
end

# minimização aplicando os princípios de Myhill-Nerode.
function minimizar_afd(afd::AFD)
    # Inicia a string de log para registrar o passo a passo.
    log = "--- Iniciando Processo de Minimização ---\n\n"

    # Passo 0: Remove estados inalcançáveis para limpar o AFD.
    afd_alcancavel = remover_estados_inalcancaveis(afd)
    log *= "Passo 0: Remoção de Estados Inalcançáveis.\n"
    log *= "Estados restantes: $(join(sort(collect(afd_alcancavel.estados)), ", "))\n\n"

    # Valida o autômato limpo antes de prosseguir.
    validacao = validar_afd(afd_alcancavel)
    if !startswith(validacao, "AFD válido."); return validacao, nothing; end

    # Verifica se o AFD já não é mínimo (1 ou 0 estados).
    if length(afd_alcancavel.estados) <= 1; return "AFD já é mínimo.", afd_alcancavel; end

    # --- Início do Algoritmo de Refinamento de Partições (Hopcroft) ---

    # Passo 1 (Base): Cria a partição inicial (Finais vs. Não-Finais).
    finais = Set(s for s in afd_alcancavel.estados if s in afd_alcancavel.finais)
    nao_finais = Set(s for s in afd_alcancavel.estados if !(s in afd_alcancavel.finais))
    particoes = [finais, nao_finais]
    filter!(!isempty, particoes)
    log *= "Passo 1: Partição Inicial (Base da Indução).\n"
    log *= "   - Grupo de Finais: {$(join(sort(collect(finais)), ", "))}\n"
    log *= "   - Grupo de Não-Finais: {$(join(sort(collect(nao_finais)), ", "))}\n\n"

    # Cria uma 'lista de trabalho' com as partições a serem refinadas.
    pendentes = [p for p in particoes if length(p) > 1]
    iteracao = 1

    log *= "Passo 2: Refinamento Iterativo das Partições (Passo Indutivo).\n"
    # Refina as partições até não haver mais mudanças.
    while !isempty(pendentes)
        P = popfirst!(pendentes) # Pega uma partição P para tentar dividi-la.
        log *= "--- Iteração $iteracao ---\n"
        log *= "Testando partição P = {$(join(sort(collect(P)), ", "))}\n"
        iteracao += 1

        # Testa a divisão de P para cada símbolo do alfabeto.
        for simbolo in afd_alcancavel.alfabeto
            log *= "  ↳ Com o símbolo: '$simbolo'\n"
            # Agrupa os estados de P com base na partição de seus destinos.
            destinos = Dict{Union{Nothing,Set},Set}()
            for s in P
                alvo = afd_alcancavel.transicoes[(s, simbolo)]
                particao_alvo = nothing
                for p_i in particoes; if alvo in p_i; particao_alvo = p_i; break; end; end
                if !haskey(destinos, particao_alvo); destinos[particao_alvo] = Set(); end
                push!(destinos[particao_alvo], s)
            end

            # Se os destinos são diferentes, a partição P deve ser dividida.
            if length(destinos) > 1
                log *= "    DIVISÃO! Os estados em P levam a partições diferentes.\n"
                filter!(p -> p != P, particoes) # Remove a partição antiga (P).
                novas_particoes = collect(values(destinos))
                for np in novas_particoes; log *= "      - Novo grupo gerado: {$(join(sort(collect(np)), ", "))}\n"; end
                append!(particoes, novas_particoes) # Adiciona os novos subgrupos, mais refinados.
                append!(pendentes, filter(p -> length(p) > 1, novas_particoes)) # Adiciona os novos subgrupos à lista de trabalho.
                break
            else
                log *= "    Sem divisão. Todos os estados em P se comportam da mesma forma para o símbolo '$simbolo'.\n"
            end
        end
        log *= "\n"
    end

    # As partições finais são as classes de equivalência.
    log *= "--- Fim do Refinamento ---\n"
    log *= "Partições finais (Classes de Equivalência):\n"
    grupos_ordenados = sort(collect(particoes), by=g -> join(sort(collect(g))))
    for (i, grupo) in enumerate(grupos_ordenados); log *= "  - M$(i-1): {$(join(sort(collect(grupo)), ", "))}\n"; end
    
    # Passo 3: Inicia a construção do novo AFD.
    log *= "\nPasso 3: Construindo o novo AFD a partir das classes de equivalência.\n"
    mapa_novo_estado = Dict()
    for (i, grupo) in enumerate(grupos_ordenados)
        # Mapeia cada estado antigo para o nome do seu novo super-estado (M0, M1...).
        nome_novo_estado = "M$(i-1)"
        for est in grupo; mapa_novo_estado[est] = nome_novo_estado; end
    end

    # Define os componentes do novo autômato.
    novos_estados = Set(values(mapa_novo_estado))
    novo_inicial = mapa_novo_estado[afd_alcancavel.inicial]
    novos_finais = Set(mapa_novo_estado[f] for f in afd_alcancavel.finais if haskey(mapa_novo_estado, f))
    novas_transicoes = Dict()
    for grupo in grupos_ordenados
        rep = first(grupo) # Pega um estado representante do grupo.
        origem = mapa_novo_estado[rep]
        for simbolo in afd_alcancavel.alfabeto
            # Cria as novas transições entre os super-estados.
            destino = mapa_novo_estado[afd_alcancavel.transicoes[(rep, simbolo)]]
            novas_transicoes[(origem, simbolo)] = destino
        end
    end

    # Monta o objeto final do AFD minimizado.
    afd_minimizado = AFD(afd_alcancavel.alfabeto, novos_estados, novo_inicial, novos_finais, novas_transicoes)
    
    # Retorna o log do passo a passo e o resultado.
    return log, afd_minimizado
end

# --- Servidor WEB ---
function afd_to_dict(afd::AFD)
    return Dict("alfabeto" => collect(afd.alfabeto), "estados" => collect(afd.estados), "inicial" => afd.inicial, "finais" => collect(afd.finais), "transicoes" => Dict("$(k[1]),$(k[2])" => v for (k, v) in afd.transicoes))
end

function minimizar_handler(req::HTTP.Request)
    headers = ["Access-Control-Allow-Origin" => "*", "Access-Control-Allow-Methods" => "POST, OPTIONS", "Content-Type" => "application/json"]
    if HTTP.method(req) == "OPTIONS"
        return HTTP.Response(200, headers)
    end

    body = String(req.body)
    afd_ou_erro = ler_afd_de_string(body)
    if typeof(afd_ou_erro) == String
        return HTTP.Response(400, headers, body=JSON.json(Dict("error" => afd_ou_erro)))
    end

    log, afd_min_ou_erro = minimizar_afd(afd_ou_erro)
    if afd_min_ou_erro === nothing
        return HTTP.Response(400, headers, body=JSON.json(Dict("error" => log)))
    end

    afd_original_processado = remover_estados_inalcancaveis(afd_ou_erro)

    # Adiciona o campo "log" à resposta JSON
    data = Dict("original" => afd_to_dict(afd_original_processado), "minimizado" => afd_to_dict(afd_min_ou_erro), "log" => log)
    return HTTP.Response(200, headers, body=JSON.json(data))
end

println("✅ Servidor Final com Log. Pronto para a apresentação em http://localhost:8080.")
HTTP.serve(minimizar_handler, "0.0.0.0", 8080)