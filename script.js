mermaid.initialize({ startOnLoad: false });

const minimizeBtn = document.getElementById("minimizeBtn");
minimizeBtn.addEventListener("click", enviarAFD);

async function enviarAFD() {
    const afdText = document.getElementById("afdInput").value;
    const minimizeBtn = document.getElementById("minimizeBtn");
    if (afdText.trim() === "") {
        alert("Por favor, insira a definição do AFD.");
        return;
    }

    minimizeBtn.disabled = true;
    minimizeBtn.innerText = "Minimizando...";

    try {
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
        
        renderizarDiagrama("original", data.original);
        renderizarDiagrama("minimizado", data.minimizado);

    } catch (error) {
        alert("Não foi possível conectar ao servidor Julia. Verifique se ele está em execução.");
    } finally {
        minimizeBtn.disabled = false;
        minimizeBtn.innerText = "Minimizar";
    }
}

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