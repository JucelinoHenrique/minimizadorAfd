# =============================================================================
# Projeto: Minimizador de Autômatos Finitos Determinísticos (AFD)
# Arquivo: minimizador_web.jl (BACKEND) - VERSÃO FINAL CORRIGIDA
# =============================================================================

# --- Bloco 1: Dependências e Estrutura de Dados ---
using HTTP
using JSON

# Define a estrutura de dados para representar um AFD.
struct AFD
    alfabeto::Set{String}
    estados::Set{String}
    inicial::String
    finais::Set{String}
    transicoes::Dict{Tuple{String, String}, String}
end


# --- Bloco 2: Parsing e Validação da Entrada ---

# Converte o texto de entrada em um objeto AFD, validando o formato (sintaxe).
function ler_afd_de_string(conteudo::String)
    if isempty(strip(conteudo)); return "Erro: O texto de entrada está vazio."; end

    # inicialização de todas as nossas variaveis 
    alfabeto = Set{String}(); estados = Set{String}(); inicial = ""; finais = Set{String}();
    transicoes = Dict{Tuple{String, String}, String}(); modo_transicao = false
    definicoes_encontradas = Set{String}()

    for (i, linha_bruta) in enumerate(split(conteudo, '\n'))

        # Remove os espaços vazios e remove comentarios 
        linha = strip(split(linha_bruta, '#')[1])

        if isempty(linha); continue; end

        # verifica se a linha começa com transicoes - so no final do texto
        if startswith(linha, "transicoes")
            if modo_transicao; return "Erro na linha $i: A seção 'transicoes' foi definida mais de uma vez."; end
            modo_transicao = true; push!(definicoes_encontradas, "transicoes"); continue
        end

        if !modo_transicao

            partes_def = split(linha, ':', limit=2)

            # verificar se está com o formato de correto 
            if length(partes_def) != 2; return "Erro de formato na linha $i: '$linha_bruta'. Esperava 'chave:valor'."; end

            chave, valor = strip.(partes_def)

            if isempty(valor); return "Erro na linha $i: A definição para '$chave' não pode ser vazia."; end
            
            # faz um filtro do texto e verifica se há espaços vazios 
            valores_split = filter!(!isempty, strip.(split(valor, ',')))

            # verifica qual é o tipo de chave e faz a união com as variaveis 
            if chave == "alfabeto"; union!(alfabeto, valores_split);
            elseif chave == "estados"; union!(estados, valores_split);
            elseif chave == "inicial"; inicial = valor;
            elseif chave == "finais"; union!(finais, valores_split);

            # caso não a chave não for conhecida     
            else; return "Erro na linha $i: Chave desconhecida '$chave'."; end
            push!(definicoes_encontradas, chave)
        else
            partes_trans = strip.(split(linha, ','))
            if length(partes_trans) != 3; return "Erro de formato na linha $i: '$linha_bruta'. Esperava 'origem,destino,simbolo'."; end
            transicoes[(partes_trans[1], partes_trans[3])] = partes_trans[2]
        end
    end

    secoes_obrigatorias = Set(["alfabeto", "estados", "inicial", "finais", "transicoes"])
    secoes_faltantes = setdiff(secoes_obrigatorias, definicoes_encontradas)
    if !isempty(secoes_faltantes); return "Erro: Faltando seções obrigatórias: $(join(collect(secoes_faltantes), ", "))."; end
    
    return AFD(alfabeto, estados, inicial, finais, transicoes)
end

# Valida a lógica interna do AFD (semântica).
function validar_afd(afd::AFD)
    if !(afd.inicial in afd.estados); return "Erro de Validade: O estado inicial '$(afd.inicial)' não está no conjunto de estados."; end
    for f in afd.finais; 
        if !(f in afd.estados); return "Erro de Validade: O estado final '$f' não está no conjunto de estados."; end; 
    end
    # Para cada estado vai ser feito uma verificação se ele existe dentro das transicoes
    for estado in afd.estados, simbolo in afd.alfabeto
        #verificação dentro do nossos estados 
        if !haskey(afd.transicoes, (estado, simbolo)); return "Erro de Validade: A transição para ('$estado', '$simbolo') não está definida."; end
    end
    return "AFD válido."
end


# --- Bloco 3: Algoritmo de Minimização ---

# Passo 0 do Algoritmo: Remove estados inalcançáveis a partir do estado inicial.
function remover_estados_inalcancaveis(afd::AFD)
    alcancados = Set([afd.inicial]); fila = [afd.inicial]
    while !isempty(fila)
        estado_atual = popfirst!(fila)
        for simbolo in afd.alfabeto
            proximo_estado = get(afd.transicoes, (estado_atual, simbolo), nothing)
            if proximo_estado !== nothing && !(proximo_estado in alcancados)
                push!(alcancados, proximo_estado); push!(fila, proximo_estado)
            end
        end
    end
    return AFD(afd.alfabeto, alcancados, afd.inicial, intersect(afd.finais, alcancados), Dict(k => v for (k, v) in afd.transicoes if k[1] in alcancados))
end

# Orquestra o processo de minimização aplicando os princípios de Myhill-Nerode.
function minimizar_afd(afd::AFD)
    # Pré-processamento para garantir.
    afd_alcancavel = remover_estados_inalcancaveis(afd)
    validacao = validar_afd(afd_alcancavel)

    #verifica se o afd não começa com AFD VALIDO 
    if !startswith(validacao, "AFD válido."); return validacao, nothing; end
    #verifica se é possivel minimizar o afd 
    if length(afd_alcancavel.estados) <= 1; return "AFD já é mínimo.", afd_alcancavel; end

    # --- Início do Algoritmo de Refinamento de Partições (Hopcroft) ---

    # Passo 1 (Base): Cria a partição inicial distinguindo Finais de Não-Finais.
    particoes = [Set(s for s in afd_alcancavel.estados if s in afd_alcancavel.finais), Set(s for s in afd_alcancavel.estados if !(s in afd_alcancavel.finais))]
    filter!(!isempty, particoes)
    
    # Adiciona partições a uma "lista de trabalho" para serem refinadas.
    pendentes = [p for p in particoes if length(p) > 1]
    
    # Passo 2 (Indução): Refina as partições iterativamente até não haver mais mudanças.
    while !isempty(pendentes)

        P = popfirst!(pendentes) # Pega uma partição para tentar dividi-la.
        
        for simbolo in afd_alcancavel.alfabeto # Testa a divisão para cada símbolo.
            # Mapeia estados de P para as partições de seus destinos.
            destinos = Dict{Union{Nothing, Set}, Set}()
            for s in P
                alvo = afd_alcancavel.transicoes[(s, simbolo)]
                particao_alvo = nothing
                for p_i in particoes; if alvo in p_i; particao_alvo = p_i; break; end; end
                if !haskey(destinos, particao_alvo); 
                    destinos[particao_alvo] = Set(); end
                push!(destinos[particao_alvo], s)
            end

            # Se os destinos caem em mais de um grupo, a partição P deve ser dividida.
            if length(destinos) > 1
                # 🐞 CORREÇÃO DO BUG: Usa filter! em vez de delete! para remover um item de um Vetor.
                filter!(p -> p != P, particoes) # Remove a partição antiga.
                
                novas_particoes = collect(values(destinos))
                append!(particoes, novas_particoes) # Adiciona as novas, menores.
                append!(pendentes, filter(p -> length(p) > 1, novas_particoes)) # Adiciona as novas à lista de trabalho.
                break
            end
        end
    end
    
    # Passo 3: Constrói o novo AFD a partir das partições finais (classes de equivalência).
    mapa_novo_estado = Dict()
    grupos_ordenados = sort(collect(particoes), by=g -> join(sort(collect(g))))
    for (i, grupo) in enumerate(grupos_ordenados)
        # Define um nome simples e consistente para cada novo estado (M0, M1...).
        nome_novo_estado = "M$(i-1)"
        for est in grupo; mapa_novo_estado[est] = nome_novo_estado; end
    end
    
    # Define os componentes do novo AFD.
    novos_estados = Set(values(mapa_novo_estado))
    novo_inicial = mapa_novo_estado[afd_alcancavel.inicial]
    novos_finais = Set(mapa_novo_estado[f] for f in afd_alcancavel.finais if haskey(mapa_novo_estado, f))
    novas_transicoes = Dict()
    for grupo in grupos_ordenados
        rep = first(grupo) # Pega um estado representante do grupo.
        origem = mapa_novo_estado[rep]
        for simbolo in afd_alcancavel.alfabeto
            # Mapeia a transição original para a transição entre os novos estados.
            destino = mapa_novo_estado[afd_alcancavel.transicoes[(rep, simbolo)]]
            novas_transicoes[(origem, simbolo)] = destino
        end
    end

    # Retorna o resultado da minimização.
    afd_minimizado = AFD(afd_alcancavel.alfabeto, novos_estados, novo_inicial, novos_finais, novas_transicoes)
    return "Minimização concluída com sucesso.", afd_minimizado
end


# --- Bloco 4: Servidor Web e Comunicação (API) ---

# Converte um objeto AFD para um dicionário (para ser enviado como JSON).
function afd_to_dict(afd::AFD)
    return Dict("alfabeto"=>collect(afd.alfabeto), "estados"=>collect(afd.estados), "inicial"=>afd.inicial, "finais"=>collect(afd.finais), "transicoes"=>Dict("$(k[1]),$(k[2])"=>v for (k,v) in afd.transicoes))
end

# Manipula as requisições HTTP do frontend.
function minimizar_handler(req::HTTP.Request)
    headers = ["Access-Control-Allow-Origin"=>"*", "Access-Control-Allow-Methods"=>"POST, OPTIONS", "Content-Type"=>"application/json"]
    if HTTP.method(req) == "OPTIONS"; return HTTP.Response(200, headers); end
    
    body = String(req.body)
    afd_ou_erro = ler_afd_de_string(body)
    if typeof(afd_ou_erro) == String; return HTTP.Response(400, headers, body=JSON.json(Dict("error" => afd_ou_erro))); end
    
    log, afd_min_ou_erro = minimizar_afd(afd_ou_erro)
    if afd_min_ou_erro === nothing; return HTTP.Response(400, headers, body=JSON.json(Dict("error" => log))); end
    
    afd_original_processado = remover_estados_inalcancaveis(afd_ou_erro)

    data = Dict("original"=>afd_to_dict(afd_original_processado), "minimizado"=>afd_to_dict(afd_min_ou_erro))
    return HTTP.Response(200, headers, body=JSON.json(data))
end

# Inicia o servidor.
println("✅ Servidor Final e Corrigido. Pronto para a apresentação em http://localhost:8080.")
HTTP.serve(minimizar_handler, "0.0.0.0", 8080)
