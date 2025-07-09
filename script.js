// Prepara a biblioteca Mermaid, instruindo-a a não renderizar nada automaticamente.
mermaid.initialize({ startOnLoad: false });

// Associa nossa função principal `enviarAFD` ao evento de clique do botão.
const minimizeBtn = document.getElementById("minimizeBtn");
minimizeBtn.addEventListener("click", enviarAFD);

/**
 * Função principal, chamada quando o botão "Minimizar" é clicado.
 */
async function enviarAFD() {
    const afdText = document.getElementById("afdInput").value;
    const minimizeBtn = document.getElementById("minimizeBtn");
    const logContainer = document.getElementById('logContainer');

    // Esconde o log de execuções anteriores antes de uma nova requisição.
    logContainer.style.display = 'none';

    if (afdText.trim() === "") {
        alert("Por favor, insira a definição do AFD.");
        return;
    }

    // Melhora a experiência do usuário mostrando um feedback de carregamento.
    minimizeBtn.disabled = true;
    minimizeBtn.innerText = "Minimizando...";

    try {
        // Envia o texto do AFD para o servidor Julia.
        const response = await fetch("http://localhost:8080", {
            method: "POST",
            headers: { "Content-Type": "text/plain" },
            body: afdText
        });

        const data = await response.json();

        if (!response.ok) {
            alert(`Erro do servidor: ${data.error || 'Erro desconhecido'}`);
            return;
        }
        
        // Verifica se o log existe na resposta e o exibe.
        if (data.log) {
            const logOutput = document.getElementById('logOutput');
            logOutput.textContent = data.log; // Usar textContent é mais seguro.
            logContainer.style.display = 'block'; // Torna o container do log visível.
        }
        
        // Renderiza os dois diagramas.
        renderizarDiagrama("original", data.original);
        renderizarDiagrama("minimizado", data.minimizado);

    } catch (error) {
        alert("Não foi possível conectar ao servidor Julia. Verifique se ele está em execução.");
        console.error("Erro de conexão:", error);
    } finally {
        // Restaura o botão ao estado normal, ocorrendo erro ou não.
        minimizeBtn.disabled = false;
        minimizeBtn.innerText = "Minimizar";
    }
}

/**
 * Renderiza um diagrama Mermaid em um elemento da página.
 */
function renderizarDiagrama(elementId, afdData) {
    const elemento = document.getElementById(elementId);
    try {
        const mermaidCode = gerarMermaid(afdData);
        elemento.innerHTML = mermaidCode;
        elemento.removeAttribute("data-processed");
        mermaid.init(undefined, elemento);
    } catch (e) {
        elemento.innerHTML = "Erro ao gerar diagrama.";
        console.error("Erro no Mermaid:", e);
    }
}

/**
 * Gera a sintaxe Mermaid a partir dos dados do AFD, usando IDs seguros.
 */
function gerarMermaid(afd) {
    let mermaidCode = "graph LR\n";
    const finaisSet = new Set(afd.finais);
    const stateIdMap = new Map();
    let idCounter = 0;
    for (const estado of afd.estados) {
        stateIdMap.set(estado, `s${idCounter++}`);
    }

    for (const [estado, safeId] of stateIdMap.entries()) {
        const displayText = estado.replace(/"/g, '#quot;');
        if (finaisSet.has(estado)) {
            mermaidCode += `    ${safeId}(("${displayText}"))\n`;
        } else {
            mermaidCode += `    ${safeId}("${displayText}")\n`;
        }
    }

    if (afd.inicial && stateIdMap.has(afd.inicial)) {
        const inicialSafeId = stateIdMap.get(afd.inicial);
        mermaidCode += `\n    style __start__ fill:none,stroke:none\n`;
        mermaidCode += `    __start__(( )) --> ${inicialSafeId}\n\n`;
    }

    const transicoesAgrupadas = {};
    for (const [key, dest] of Object.entries(afd.transicoes)) {
        const [origem, simbolo] = key.split(",");
        const origemSafeId = stateIdMap.get(origem);
        const destSafeId = stateIdMap.get(dest);
        
        if (origemSafeId && destSafeId) {
            const chaveAgrupada = `${origemSafeId},${destSafeId}`;
            if (!transicoesAgrupadas[chaveAgrupada]) {
                transicoesAgrupadas[chaveAgrupada] = [];
            }
            transicoesAgrupadas[chaveAgrupada].push(simbolo);
        }
    }

    for (const [key, simbolos] of Object.entries(transicoesAgrupadas)) {
        const [origemSafeId, destSafeId] = key.split(",");
        const label = simbolos.join(',').replace(/"/g, '#quot;');
        mermaidCode += `    ${origemSafeId} -- "${label}" --> ${destSafeId}\n`;
    }

    return mermaidCode;
}
