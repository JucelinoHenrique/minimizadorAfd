Minimizador de Autômatos Finitos Determinísticos (AFD)
📖 Descrição
Esta é uma aplicação web que implementa o algoritmo de minimização de estados de um Autômato Finito Determinístico (AFD), baseado nos princípios do Teorema de Myhill-Nerode. A aplicação possui uma arquitetura cliente-servidor, com o backend de processamento lógico desenvolvido em Julia e o frontend interativo construído com HTML, CSS e JavaScript.

O usuário pode inserir a definição de um AFD em um formato de texto simples, e a aplicação visualiza o autômato original e o seu equivalente mínimo, com o menor número de estados possível.

🛠️ Tecnologias Utilizadas
Backend
Julia: Linguagem de programação de alto desempenho utilizada para toda a lógica de negócio.

HTTP.jl: Biblioteca para criar o servidor web que recebe as requisições.

JSON.jl: Biblioteca para a serialização e desserialização de dados no formato JSON, usado na comunicação com o frontend.

Frontend
HTML5: Estrutura da página web.

CSS3: Estilização moderna e responsiva da interface.

JavaScript (ES6+): Lógica do cliente, manipulação do DOM e comunicação com a API do backend.

Mermaid.js: Biblioteca JavaScript para renderizar os diagramas e grafos dos autômatos de forma declarativa.

📂 Estrutura do Projeto
O projeto está organizado na seguinte estrutura de arquivos:

/MinimizadorAFD/
├── 📄 minimizador_web.jl      # O servidor backend em Julia
├── 📄 index.html              # A página principal (estrutura)
├── 📄 style.css               # A folha de estilos (aparência)
└── 📄 script.js               # A lógica do frontend (interatividade)

🚀 Como Executar
Para rodar a aplicação, siga os passos abaixo:

Pré-requisitos
Ter o Julia instalado no seu sistema.

1. Instalar Dependências do Backend
Abra o terminal do Julia (REPL) e instale as bibliotecas HTTP e JSON:

using Pkg
Pkg.add("HTTP")
Pkg.add("JSON")

2. Iniciar o Servidor Backend
Navegue pelo seu terminal comum (CMD, PowerShell, etc.) até a pasta raiz do projeto e execute o seguinte comando:

julia minimizador_web.jl

Você verá uma mensagem de confirmação no terminal. Deixe este terminal aberto, pois ele é o servidor que está rodando.

✅ Servidor Final e Corrigido. Pronto para a apresentação em http://localhost:8080.

3. Abrir a Aplicação no Navegador
Na pasta do projeto, dê um duplo clique no arquivo index.html. Ele será aberto no seu navegador padrão e a aplicação estará pronta para uso.

📝 Formato do Arquivo de Entrada
A aplicação espera a definição do AFD em um formato de texto específico, que deve ser colado na área de texto da interface. As seções obrigatórias são: alfabeto, estados, inicial, finais e transicoes.

Exemplo de Formato:
# Comentários podem ser adicionados com o símbolo '#'
alfabeto:a,b
estados:q0,q1,q2
inicial:q0
finais:q2
transicoes
q0,q0,a
q0,q1,b
q1,q0,a
q1,q2,b
q2,q0,a
q2,q2,b
