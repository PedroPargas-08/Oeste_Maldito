```{=html}
<!-- Página 1 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 1 OESTE MALDITO BÍBLIA DE
REGRAS E ESPECIFICAÇÃO FUNCIONAL DO SITE VERSÃO 7 Weird West • RPG de
one-shot • Regras de jogo • Requisitos do sistema Documento consolidado
em 31 de outubro de 2026 Documento principal de mecânicas e
implementação. O conteúdo narrativo permanece em arquivo separado.

------------------------------------------------------------------------

```{=html}
<!-- Página 2 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 2 CONTROLE DO DOCUMENTO Campo
Definição Versão V7 --- 31/10/2026 Finalidade Consolidar regras
aprovadas e orientar uma IA/desenvolvedor na criação do site. Escopo Uma
única one-shot, até 5 jogadores e um mestre. Backend previsto Supabase
--- autenticação, banco de dados, RLS e armazenamento. Organização Esta
Bíblia contém regras e requisitos funcionais. Lore e fichas individuais
ficam no Bestiário/Compêndio de Lore. Autoridade: o usuário é a
autoridade final. Nenhuma sugestão, lacuna ou interpretação técnica pode
virar regra oficial sem aprovação. COMO LER ESTA BÍBLIA Termo
Significado APROVADO Decisão definida pelo usuário. NARRATIVO / MESTRE
Resolução contextual sob responsabilidade do mestre, sem fórmula
universal. PENDENTE Ainda não definido; não implementar como regra
definitiva. FORA DO ESCOPO Não desenvolver nesta versão. Em caso de
conflito, prevalece a decisão mais recente e explícita do usuário. Não
preencher lacunas com invenções. SUMÁRIO PARTE I --- Regras do RPG 1.
Escopo e princípios 2. Criação de personagem 3. Atributos e perícias 4.
Testes 5. PV e Espírito 6. Recuperação 7. Combate 8. Armas e
equipamentos 9. Habilidades e Marcas 10. Condições PARTE II ---
Especificação do site 11. Escopo do produto 12. Contas e permissões 13.
Lobby e aprovação 14. Fichas 15. Histórico e auditoria 16. Inventário
17. Habilidades 18. Combate no site 19. Condições 20. Diário e
biblioteca 21. Enciclopédia 22. Painéis 23. Montarias

------------------------------------------------------------------------

```{=html}
<!-- Página 3 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 3 24. Conquistas e galeria
25. Anotações 26. Finanças 27. Personalização 28. Encerramento e arquivo
29. Backups 30. Auditoria 31. Segurança 32. Exclusões 33. Pendências e
diretrizes

------------------------------------------------------------------------

```{=html}
<!-- Página 4 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 4 PARTE I --- REGRAS DO
RPG 1. ESCOPO E PRINCÍPIOS • Oeste Maldito é um RPG de Weird West para
uma aventura curta, planejada para aproximadamente 2 a 3 sessões. • A
Bíblia registra somente regras necessárias para jogar e requisitos
genéricos para orientar o site. • Não é uma enciclopédia do cenário.
História, NPCs, criaturas, líderes, gangues, regiões, rituais,
acontecimentos e fichas individuais pertencem ao Bestiário/Compêndio de
Lore. • O mestre é a autoridade final sobre a sessão, encontros, fichas
e decisões narrativas. • O sistema não deve presumir fórmulas ou
comportamentos ainda não definidos. Separação obrigatória: esta Bíblia
contém mecânicas e especificações do site. O Bestiário/Compêndio
separado contém lore, NPCs, criaturas, fichas individuais, poderes
específicos, rituais e conteúdo narrativo. 2. CRIAÇÃO DE PERSONAGEM •
Todos os seis atributos começam em 1; cada jogador recebe 24 pontos
adicionais para distribuir; máximo 10 por atributo. • As 12 perícias
começam em 0; cada jogador recebe 15 pontos para distribuir; máximo 3
por perícia na criação. • Cada ponto de perícia concede +1 ao teste
pertinente. • Não há XP, níveis ou evolução numérica de
atributos/perícias durante a one-shot. • Alterações posteriores de
atributos e perícias dependem de autorização do mestre. O site valida a
distribuição, impede ultrapassar limites e impede envio inválido. O
mestre pode corrigir valores e completar fichas. 3. ATRIBUTOS E PERÍCIAS
Atributo Uso principal Mira Precisão com armas de disparo, pontaria e
tiros em movimento. Vigor Saúde, força e resistência; determina PV
máximo. Agilidade Reflexos, movimento, furtividade, destreza e cavalgar.
Astúcia Percepção, investigação, rastreamento e medicina de campo.
Carisma Persuasão, intimidação, negociação, blefe e liderança. Espírito
Resistência a horrores/maldições e canalização de energia mística.
Perícia Atributo Uso Atletismo Vigor Correr, saltar, escalar e esforço
físico. Briga Vigor Socos, chutes, agarrões e luta corporal.
Sobrevivência Astúcia Encontrar água, alimento, abrigo e sobreviver.
Atirar Mira Pistolas, rifles e outras armas de disparo. Cavalgar
Agilidade Montar, controlar e manobrar cavalos. Investigar Astúcia
Examinar locais, encontrar pistas e solucionar mistérios. Percepção
Astúcia Notar movimentos, sons, detalhes e emboscadas. Medicina Astúcia
Tratar ferimentos e prestar primeiros socorros. Furtividade Agilidade
Esconder-se e mover-se silenciosamente. Persuadir Carisma Convencer,
negociar e influenciar. Intimidar Carisma Ameaçar, pressionar e impor
respeito. Ocultismo Espírito Conhecer fenômenos sobrenaturais, maldições
e rituais.

------------------------------------------------------------------------

```{=html}
<!-- Página 5 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 5 4. TESTES Teste padrão:
1d20 + atributo + uma perícia pertinente, quando houver. O resultado
deve ser igual ou superior à CD. • Um teste utiliza um atributo e, no
máximo, uma perícia. • Sem perícia adequada, o teste pode usar somente o
atributo. • O mestre escolhe atributo, perícia e CD conforme a situação.
CD de referência (não definitiva) Valor Muito fácil 8 Fácil 11 Moderada
14 Difícil 17 Muito difícil 20 Extrema 23 Quase impossível 26 O 20
natural tem efeitos específicos aprovados em combate. Fora dos casos
definidos, a aplicação de resultados naturais fica a critério do mestre.
5. RECURSOS: PV E ESPÍRITO 5.1 Pontos de vida Todos os humanos ---
jogadores, NPCs, civis e bandidos --- usam a mesma escala. PV máximo é
determinado por Vigor. Vigor PV máximo 1 300 2 333 3 367 4 400 5 433 6
467 7 500 8 533 9 567 10 600 Fórmula: PV = 300 + (Vigor − 1) × 300/9,
arredondado ao inteiro mais próximo.

------------------------------------------------------------------------

```{=html}
<!-- Página 6 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 6 5.2 Espírito Atributo
Espírito Reserva máxima 1 200 2 222 3 244 4 267 5 289 6 311 7 333 8 356
9 378 10 400 Fórmula: Espírito máximo = 200 + (Espírito − 1) × 200/9,
arredondado ao inteiro mais próximo. • Uma ação carregada com energia
sobrenatural custa 10 Espírito. • Qualquer personagem com Espírito
suficiente pode carregar ataque/disparo; não precisa possuir Marca. •
Ataques comuns não causam dano real a criaturas sobrenaturais; ataques
carregados causam. • 10 é o custo genérico; exceções podem ser
configuradas pelo mestre para habilidades individuais. • Equipamento
especial não gasta Espírito apenas por ser especial. 6. RECUPERAÇÃO E
TRATAMENTO Método Recuperação de PV máximo Descanso curto 20% Descanso
longo 60% Tratamento médico bem-sucedido 80% • A recuperação é calculada
sobre PV máximo, não PV atual; pode acumular, sem ultrapassar o máximo.
• Qualquer personagem pode tentar tratar ferimentos. • Sem Medicina:
teste de Astúcia. Com Medicina: Astúcia + Medicina. • Sucesso no
tratamento recupera 80% do PV máximo. • Consequências de falha e
frequência de tratamentos ficam a critério do mestre. • Espírito só é
recuperado durante descansos; curto e longo restauram a reserva inteira.
• Tratamento médico não recupera Espírito. • A Marca da Devoração é
exceção específica de recuperação por essência; detalhes ficam no
compêndio. Não existe atributo, barra ou reserva numérica de sanidade.
Consequências psicológicas são narrativas; o site não deve criar sistema
numérico de sanidade. 7. COMBATE 7.1 Iniciativa, movimento e ações •
Iniciativa: 1d20 + Agilidade; maior resultado age primeiro. • Mapa,
quando usado fora do site, utiliza quadrados de 1 m × 1 m. •
Deslocamento por turno: 5 + Agilidade metros. • Cada personagem pode
realizar um movimento e uma ação principal por turno. • 20 natural em
combate concede uma ação extra; exemplos definidos: movimento adicional
ou segundo disparo. • 20 natural não concede multiplicador nem bônus
especial de dano corpo a corpo. • Usos do crítico em outras modalidades
ainda não especificadas ficam a critério do mestre. 7.2 Ataques corpo a
corpo • Desarmado: 1d20 + Vigor + Briga. • Arma branca/lâmina: 1d20 +
Vigor + Briga.

------------------------------------------------------------------------

```{=html}
<!-- Página 7 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 7 • Se o alvo percebe o
ataque, há disputa entre ataque e defesa. • Empate: desempate com 1d20
puro, sem atributos/perícias; repetir até haver vencedor. • Agarrões,
imobilizações, derrubadas, desarmes e outras situações especiais são
narrativos. 7.3 Defesa e redução Defesa: 1d20 + Vigor. Referência fixa
10. A disputa determina se o golpe vence a defesa; o resultado da defesa
determina a redução. Resultado final da defesa Redução 1--9 0% 10 10% 11
20% 12 30% 13 40% 14 50% 15 60% 16 70% 17 80% 18 ou mais 90% 20 natural
no dado 100% Mesmo se perder a disputa, o defensor aplica a redução
correspondente à sua rolagem. 20 natural na defesa substitui a tabela e
reduz 100%. 7.4 Alvo desprevenido e dano Se o alvo não percebe o ataque
a tempo, o ataque é garantido, não há defesa e o dano é integral, sem
redução. Ataque Dano Desarmado Vigor + 1d20 Lâmina Vigor + 2d20 (somar
dados) Arma de fogo Valor fixo da ficha Perda de PV não gera penalidade
numérica automática. Ferimentos são narrativos, salvo regra específica.
7.5 Armas de fogo • Alcance efetivo = alcance da arma + Mira. • CD do
disparo = distância entre atirador e alvo, em metros. • Teste: 1d6 +
Mira + Atirar. Acerta se resultado ≥ CD; abaixo disso, erra. • Acerto
aplica dano fixo da ficha, sem rolagem adicional. •
Variação/consequência do dano conforme distância é narrativa. • O mestre
decide se o alvo está longe o suficiente para tentar esquiva; não é
automática. • Efeitos como perfuração, explosão ou múltiplos alvos são
individuais; não há tabela universal. 7.6 Esquiva humana Resultado
natural d20 Consequência 1 Falha crítica: recebe dois ataques. 2--14
Falha: recebe o golpe integral. 15--19 Sucesso: desvia completamente. 20
Sucesso crítico: desvia e ganha turno extra para contra-atacar. • O
mestre solicita esquiva quando considerar apropriado. • A referência
humana não recebe modificador de Agilidade. • Possibilidade de esquiva
contra tiros é decidida narrativamente pelo mestre.

------------------------------------------------------------------------

```{=html}
<!-- Página 8 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 8 7.7 Cobertura e situações
especiais Cobertura é narrativa: o mestre decide se bloqueia, reduz ou
permite atravessar o ataque. Não há fórmula universal. Ataques errados,
retirada do corpo a corpo e desvantagem numérica não geram penalidades
automáticas. 8. ARMAS, INVENTÁRIO E EQUIPAMENTOS • Armas possuem
registro próprio com dano, alcance e munição, além de
propriedades/efeitos quando houver. • Armas de fogo causam dano fixo
cadastrado. Armas brancas/desarmadas seguem as regras acima. • Não
existe tabela universal obrigatória; itens são cadastrados pelo mestre.
• Jogador organiza inventário e escolhe itens equipados, mas só pode
equipar o que possui. 9. HABILIDADES E MARCAS --- SISTEMA GENÉRICO • A
Bíblia define somente a estrutura genérica; poderes individuais não são
detalhados aqui. • Cada habilidade deve permitir nome, descrição, tipo,
efeito, requisitos, custo, limitações e parâmetros necessários. •
Suportar habilidades passivas e ativáveis. • Custo genérico
sobrenatural: 10 Espírito por uso, salvo exceção configurada pelo
mestre. • Antes de ativar, verificar requisitos e recursos; descontar
custo configurado e registrar uso. • O mestre pode adicionar, editar,
remover e configurar habilidades. • Os poderes específicos das cinco
Marcas pertencem ao Bestiário/Compêndio de Lore. O motor deve ser
configurável; não codificar permanentemente efeitos individuais no
sistema central. 10. CONDIÇÕES E EFEITOS TEMPORÁRIOS • Utilizar lista de
condições pré-cadastradas; não criar condições personalizadas durante a
aventura. • Mestre aplica, edita, define/atualiza duração e remove
condições. • Jogadores visualizam condição, efeito e duração, mas não
removem. • Nenhuma condição é removida automaticamente ao terminar
duração estimada; mestre controla manualmente. • Efeitos mecânicos são
definidos individualmente; não presumir penalidades universais.

------------------------------------------------------------------------

```{=html}
<!-- Página 9 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 9 PARTE II --- ESPECIFICAÇÃO
FUNCIONAL DO SITE 11. ESCOPO DO PRODUTO • Site exclusivo para uma única
one-shot; não é plataforma de múltiplas campanhas. • Até 5 jogadores e
um mestre. • Supabase será o backend. • Segurança deve ser garantida no
backend por RLS e validação de permissões; ocultar elementos na
interface não basta. • Iniciar a construção do site cedo para permitir
validação visual e funcional. • Não apresentar conteúdo pendente como
definitivo. 12. CONTAS, AUTENTICAÇÃO E PAPÉIS • Login/cadastro com
e-mail e senha; recuperação de senha. • Cada participante possui conta
individual. • Novas contas são jogadores por padrão. • Papel de mestre é
atribuído diretamente no banco de dados; jogador não altera o próprio
papel. • Mestre é autoridade principal, com acesso administrativo total.
• Permissões devem ser validadas no backend e protegidas por RLS. 13.
LOBBY, CONVITE E APROVAÇÃO • Convite por link ou código. • Entrada
depende de aprovação manual do mestre. • Mestre verifica identidade do
participante e ficha correta antes de aprovar. • Jogador não pode
assumir ficha de outro sem autorização. • Jogador pode preencher ficha e
enviar para aprovação. • Mestre pode aprovar ficha parcialmente
preenchida e completar depois. • Estados da ficha: rascunho, pendente,
aprovada ou incompleta. 14. FICHAS E PERMISSÕES 14.1 Duas áreas
independentes Área Conteúdo Ficha mecânica Atributos, perícias, PV,
Espírito, armas, equipamentos, munição, habilidades, condições e dados
de cálculo. Perfil narrativo Nome/apelido, aparência, personalidade,
história, relações e detalhes interpretativos. 14.2 Edição • Jogador
edita livremente seu perfil narrativo. • Jogador não altera
atributos/perícias livremente; exige autorização do mestre. • Jogador
pode atualizar PV e Espírito durante a sessão dentro das ações
permitidas. • Mestre cria, edita e apaga qualquer ficha e qualquer
informação. • Mestre pode preencher atributos, perícias, recursos,
equipamentos, habilidades/Marcas e perfil narrativo. • Mestre pode
aprovar ficha incompleta e completar campos necessários. • Site
identifica campos pendentes e indica quando a ficha está pronta. 14.3
Cálculos • PV máximo é calculado automaticamente por Vigor conforme
tabela/fórmula aprovada. • Espírito máximo é calculado automaticamente
pelo atributo Espírito. • Alteração de Vigor/Espírito pelo mestre
recalcula o máximo correspondente. • Valor atual permanece sob controle
do mestre; não sobrescrever silenciosamente o atual ao recalcular
máximo.

------------------------------------------------------------------------

```{=html}
<!-- Página 10 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 10 15. HISTÓRICO DE RECURSOS
• Jogadores atualizam PV/Espírito por dano, recuperação, gasto etc.;
mestre pode corrigir tudo. • Registrar responsável, personagem afetado,
campo, valor anterior/novo, tipo da alteração, data e horário. • Tipos
incluem dano, recuperação, gasto e correção. • Registrar ações de
jogadores e mestre. • Jogadores não podem editar/apagar histórico;
mestre pode consultar. 16. INVENTÁRIO, ARMAS E EQUIPAMENTOS • Jogador
visualiza e organiza próprio inventário e escolhe itens
equipados/utilizados. • Mestre adiciona, remove e edita itens,
quantidades e propriedades em qualquer inventário. • Uso de itens gera
histórico. • Munição é descontada ao disparar; medicamentos e tônicos ao
usar. • Bloquear disparo/consumo se quantidade for insuficiente. •
Mestre pode fazer ajustes manuais. • Jogador pode trocar livremente
equipamento durante a sessão se possuir o item; trocas atualizam estado
e histórico. • Não permitir equipar item que não possui. 17. HABILIDADES
NO SITE • Ficha mostra habilidades disponíveis, descrição, efeitos,
requisitos e custo. • Jogador pode ativar pelo site quando cumprir
requisitos. • Validar requisitos e recursos; descontar Espírito conforme
custo configurado. • Uso é registrado no histórico. • Mestre adiciona,
remove e edita habilidades, custos, efeitos, requisitos e limitações. •
Mestre consulta histórico e corrige recursos. • Suportar habilidades
passivas/ativáveis e novos cadastros sem reprogramar o motor para cada
poder. • Detalhes individuais das Marcas vêm do compêndio e são
configurados pelo mestre. 18. COMBATE NO SITE 18.1 Mestre e jogadores •
Área de combate controlada pelo mestre: iniciar/encerrar encontro,
selecionar participantes, controlar turnos e acompanhar PV/Espírito,
armas, equipamentos e habilidades. • Jogadores visualizam combate, sua
situação e realizam ações permitidas no turno. • Mestre registra
acontecimentos e pode encerrar combate manualmente, mesmo sem todos
derrotados. • Não haverá mapa tático integrado; o grupo usa plataforma
externa. 18.2 Iniciativa e rolagens • Site rola automaticamente 1d20 +
Agilidade e ordena maior para menor. • Mestre pode corrigir resultados e
alterar ordem manualmente; ordem é visível aos jogadores. • Alterações
manuais são registradas no histórico. • Ferramenta de rolagem é
exclusiva do mestre: escolhe dado e modificadores, rola atributos,
perícias, iniciativa, ataques e esquivas. • Jogadores não usam
ferramenta; acompanham resultados que o mestre decidir compartilhar. •
Mestre define se cada rolagem é pública ou privada. 18.3 Histórico de
combate • Registrar data/duração, participantes, iniciativa, danos
causados/recebidos, gastos de Espírito, habilidades usadas, condições
aplicadas/removidas, resultados e acontecimentos importantes. • Mestre
consulta históricos; ao encerrar combate, histórico é salvo. 19.
CONDIÇÕES NO SITE • Mestre aplica, edita, atualiza duração e remove
condições pré-cadastradas.

------------------------------------------------------------------------

```{=html}
<!-- Página 11 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 11 • Jogadores visualizam
condições/efeitos/duração, sem permissão para remover. • Não remover
automaticamente ao fim da duração estimada. • Não permitir criação livre
de condições durante a aventura. 20. DIÁRIO E BIBLIOTECA 20.1 Diário •
Mestre cria/edita/exclui registros de acontecimentos, pistas,
descobertas e informações importantes. • Organização por sessão e data;
cada registro pode ser público ou privado. • Jogadores consultam apenas
registros compartilhados. 20.2 Biblioteca • Mestre envia imagens, PDFs,
documentos e materiais; organiza pastas/categorias, renomeia e exclui. •
Mestre define o que é compartilhado. • Jogadores visualizam/baixam
arquivos compartilhados. • Usar Supabase Storage com permissões
adequadas. 21. ENCICLOPÉDIA DE REGRAS • Área de consulta para mestre e
jogadores. • Categorias: atributos/perícias, testes, criação,
combate/iniciativa, armas/munição, PV/Espírito, descansos,
esquiva/defesa, habilidades/Marcas e equipamentos/inventário. • Conteúdo
alimentado pela Bíblia. • Mestre oculta/libera categorias e regras
individualmente; jogadores veem apenas o liberado. 22. PAINÉIS E
CONSULTA RÁPIDA Jogador: consulta atributos, perícias, PV atual/máximo,
Espírito atual/máximo, armas equipadas, munição, habilidades e
condições. Mestre: painel geral de todos os personagens com
nome/jogador, PV, Espírito, condições, armas equipadas, estado da ficha
e situação na sessão. Pode abrir qualquer ficha. 23. MONTARIAS • Seção
exclusivamente narrativa: nome, tipo de animal, aparência,
características narrativas, condição atual e outros detalhes. • Sem PV,
atributos, perícias, velocidade calculada ou resistência numérica. •
Jogador edita nome/aparência/descrição narrativa; mestre edita tudo. 24.
CONQUISTAS, MEMÓRIAS E GALERIA 24.1 Conquistas • Mestre cria conquista
com nome, descrição, imagem, personagem, data e categoria opcional. •
Jogador vê as próprias conquistas e motivo/data; pode ver outras quando
compartilhadas. • Conquistas são recreativas, sem bônus mecânicos. •
Galeria pública no lobby para conquistas compartilhadas. • Mestre
controla criação, edição, publicação e remoção; pode usar upload próprio
ou biblioteca. 24.2 Galeria de imagens • Mestre envia artes, mapas
ilustrativos, retratos e momentos da sessão; organiza álbuns/categorias,
títulos e descrições. • Mestre remove/substitui imagens. • Jogadores
podem enviar imagens/descrições, mas publicação depende de aprovação do
mestre. • Somente imagens aprovadas ficam visíveis a todos.

------------------------------------------------------------------------

```{=html}
<!-- Página 12 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 12 25. ANOTAÇÕES PRIVADAS •
Cada jogador tem bloco privado com título/conteúdo,
criar/editar/excluir. • Somente o próprio jogador acessa; nem o mestre
pode ler. • Privacidade deve ser imposta por RLS, não apenas interface.
• Mestre também tem bloco privado próprio, separado do diário e
invisível aos jogadores. 26. SISTEMA FINANCEIRO • Saldo em dólar
americano (US\$) na ficha. • Mestre adiciona/remove dinheiro, registra
pagamentos/recompensas, controla compras/dívidas e consulta histórico. •
Jogador consulta saldo, registra compras/pagamentos e acompanha
dívidas/transações. • Movimentações geram histórico; mestre pode
consultar e corrigir. • Não existe loja ou catálogo: transações são
registradas diretamente nas fichas/inventários. 27. CONFIGURAÇÕES E
PERSONALIZAÇÃO • Painel exclusivo do mestre para nome, descrição,
apresentação interna, regras visíveis, configurações da sessão e
informações do lobby. • Personalização visual: cores
principais/secundárias, fundo, logotipo/identidade, imagens de
apresentação e tema claro/escuro. • Alterações visuais são aplicadas a
todos. 28. ENCERRAMENTO E MODO DE ARQUIVO • Tela de encerramento com
resumo, personagens, conquistas, momentos marcantes, resultados finais,
galeria e estatísticas quando houver dados. • Mestre revisa/controla o
encerramento antes de publicar. • Após encerramento, entra em Modo de
Arquivo: fichas, diário, combates, conquistas e imagens continuam
consultáveis; alterações normais ficam bloqueadas. • Mestre mantém
acesso administrativo para correções. • Mestre pode reabrir aventura;
Modo de Arquivo é suspenso, funcionalidades normais retornam e sessões
adicionais podem ocorrer. • Registros anteriores são preservados;
aventura pode ser encerrada novamente. • Cada encerramento e reabertura
é registrado no histórico. 29. BACKUPS E RESTAURAÇÃO • O sistema deve
prever mecanismos de backup e restauração dos dados da aventura. •
Somente o mestre pode restaurar um backup. • A autorização é validada no
backend, não apenas por botão oculto. • A restauração é registrada no
histórico/auditoria. PENDENTE: frequência de criação, retenção, seleção
de pontos e detalhes de confirmação/recuperação não foram definidos. Não
inventar política automática. 30. PAINEL DE AUDITORIA • Painel exclusivo
do mestre reunindo ações importantes de jogadores e mestre. • Registrar
alterações em fichas/recursos, uso de habilidades/itens,
inventário/equipamentos, movimentações financeiras,
aprovações/rejeições, alterações de combate/condições,
encerramento/reabertura e restauração de backups. • Cada registro
identifica responsável, ação, registro/personagem afetado, data/horário
e detalhes pertinentes. • Jogadores não podem alterar/apagar registros.
• Auditoria complementa os históricos específicos; não os substitui. 31.
SEGURANÇA, DADOS E ARMAZENAMENTO • Supabase para autenticação, banco de
dados e arquivos.

------------------------------------------------------------------------

```{=html}
<!-- Página 13 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 13 • Aplicar RLS nas tabelas
com dados de usuários, personagens, permissões e conteúdo privado. •
Validar autorização no backend em toda operação sensível. • Jogador não
pode alterar papel próprio nem acessar dados de outro sem permissão. •
Anotações privadas devem ter isolamento por usuário, inclusive contra
acesso do mestre. • Arquivos no Storage obedecem às permissões de
compartilhamento. • Históricos e auditoria não podem ser
editados/apagados por jogadores. • Erros de permissão devem ser claros
sem expor dados privados. Segurança deve ser garantida no banco/backend.
Controles de interface são complementares e nunca substituem RLS e
validações. 32. EXCLUSÕES EXPLÍCITAS Item Decisão Múltiplas campanhas
Não; uma única one-shot. Mapa tático integrado Não; usar plataforma
externa. Notificações em tempo real Não haverá sistema de notificações.
Avisos no lobby Não haverá. Loja/catálogo Não haverá. Área separada de
segredos do mestre Fora do escopo atual. Condições personalizadas
durante a sessão Não haverá. Sanidade numérica Não haverá
atributo/barra/reserva. Exportação geral Não haverá exportação em PDF ou
planilhas. Página pública de apresentação Não haverá; acesso começa no
login/cadastro. A ausência de uma funcionalidade nesta tabela não
autoriza sua criação automática. Novas funções precisam de aprovação.
33. PENDÊNCIAS E DIRETRIZES 33.1 Pendências de regra • Aplicação do 20
natural em modalidades ainda não especificadas. • Detalhes mecânicos de
cada condição individual. • Parâmetros individuais de armas e
habilidades (dano, alcance, munição, efeitos e limitações) nas
fichas/compêndio apropriados. • Procedimentos de ataque não cobertos
pelas modalidades definidas. • Detalhes situacionais de esquiva quando o
mestre considerar necessário. 33.2 Pendências funcionais/técnicas •
Frequência e retenção dos backups; seleção de ponto e confirmação de
restauração. • Detalhes técnicos de retenção dos logs. • Modelo
definitivo de tabelas, relacionamentos e migrações, sem alterar regras
aprovadas. • Refinamento visual/fluxos da interface durante validação,
sem alterar permissões ou mecânicas. 33.3 Diretrizes para
IA/desenvolvedor • Ler esta Bíblia integralmente antes de implementar. •
Não misturar Bestiário/Compêndio de Lore com a Bíblia de Regras. • Não
inventar regras, efeitos, nomes, acontecimentos, fichas ou lore. •
Distinguir decisões aprovadas, sugestões e pendências. • Não implementar
pendências como definitivas. • Manter configuráveis os valores e efeitos
individuais definidos pelo mestre. • Implementar RLS e validações de
autorização no Supabase. • Preservar dados existentes em migrações;
evitar operações destrutivas. • Iniciar a interface cedo para testes
visuais.

------------------------------------------------------------------------

```{=html}
<!-- Página 14 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 14 • Não adicionar sistemas
fora do escopo sem aprovação.

------------------------------------------------------------------------

```{=html}
<!-- Página 15 -->
```
Oeste Maldito • Bíblia de Regras V7 Página 15 REGISTRO DE ALTERAÇÕES ---
V7 A V7 redefine a organização documental. A Bíblia principal passa a
conter exclusivamente regras de jogo e requisitos funcionais do site. O
conteúdo narrativo é transferido para o Bestiário e Compêndio de Lore. •
Consolidação de atributos, perícias, testes, PV, Espírito, recuperação,
combate, esquiva, armas e condições. • Consolidação dos requisitos de
autenticação, papéis, aprovação, fichas, inventário, habilidades,
combate, diário, biblioteca, enciclopédia, painéis, montarias,
conquistas, galeria, anotações, finanças e personalização. • Inclusão de
encerramento, Modo de Arquivo, reabertura, backups com restauração
exclusiva do mestre e painel de auditoria. • Registro das exclusões
aprovadas: sem exportação geral, sem landing page pública, sem loja, sem
mapa tático integrado, sem notificações/avisos e sem múltiplas
campanhas. Esta versão registra as decisões disponíveis e aprovadas até
31 de outubro de 2026. Alterações futuras deverão ser incorporadas em
nova revisão, preservando o histórico de versões.
