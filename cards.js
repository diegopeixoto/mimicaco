// Categorias e cartas do Mimicaço da Turma do Rawzinho, separadas por nível.
// kids: crianças pequenas; familia: crianças maiores e família; adulto: expressões, situações e conceitos difíceis.
// Edite à vontade: cada categoria tem uma lista de palavras por nível.
const LEVELS = {
  kids: { name: 'Fácil', sub: 'Crianças', emoji: '🌼', minAge: 0 },
  familia: { name: 'Médio', sub: 'Família', emoji: '🏝️', minAge: 9 },
  adulto: { name: 'Difícil', sub: 'Adultos', emoji: '🌋', minAge: 15 },
};

const CATEGORIES = {
  acao: {
    name: 'Ação', emoji: '🏃', color: '#ff8a3d',
    words: {
      kids: ['Escovar os dentes', 'Pular corda', 'Andar de bicicleta', 'Tomar banho', 'Fazer um bolo', 'Pescar',
      'Tirar uma foto', 'Dirigir um carro', 'Lavar a louça', 'Nadar', 'Dar banho no cachorro', 'Soprar velinhas',
      'Jogar bola', 'Chutar a bola', 'Pintar um quadro', 'Plantar uma flor', 'Remar um barco', 'Andar de patins',
      'Comer pipoca', 'Fazer yoga', 'Descascar uma banana', 'Tocar bateria', 'Pentear o cabelo', 'Amarrar o tênis',
      'Soltar pipa', 'Abrir um presente', 'Dormir', 'Acordar com preguiça', 'Espirrar', 'Fazer bolinhas de sabão',
      'Tomar sorvete', 'Brincar de esconde-esconde', 'Pular na cama', 'Varrer o chão', 'Ler um livro', 'Andar na chuva',
      'Subir uma escada', 'Escorregar no escorregador', 'Balançar no balanço', 'Fazer um boneco de neve'],
      familia: ['Trocar pneu', 'Montar uma barraca', 'Fazer malabarismo', 'Surfar', 'Escalar uma montanha', 'Andar de skate', 'Jogar boliche', 'Pintar uma parede', 'Passar roupa', 'Costurar', 'Fazer churrasco', 'Tirar selfie', 'Pular de paraquedas', 'Andar a cavalo', 'Jogar tênis', 'Fazer flexões', 'Mergulhar', 'Patinar no gelo', 'Lutar karatê', 'Tocar violino', 'Jogar videogame', 'Regar as plantas', 'Fazer pizza', 'Encher um balão', 'Arrumar a mala', 'Estourar plástico bolha', 'Lavar o carro', 'Montar um quebra-cabeça', 'Jogar xadrez', 'Pescar e o peixe fugir', 'Jogar vôlei', 'Fazer origami', 'Andar de monociclo', 'Esquiar', 'Dar um mortal'],
      adulto: ['Fazer a declaração do imposto de renda', 'Pedir aumento ao chefe', 'Montar móvel sem manual', 'Fazer baliza', 'Trocar a fralda do bebê', 'Pagar boleto no último dia', 'Fazer uma entrevista de emprego', 'Pedir em casamento', 'Tirar a carteira de motorista', 'Fazer reunião online sem câmera', 'Procurar vaga no estacionamento', 'Desentupir a pia', 'Fazer meditação', 'Correr uma maratona', 'Esconder a nota do restaurante', 'Ninar um bebê que não dorme', 'Arrumar a casa antes da visita', 'Tentar sair de um grupo de WhatsApp', 'Responder e-mail de madrugada', 'Fazer trilha', 'Cortar o próprio cabelo', 'Pintar as unhas', 'Fazer barba', 'Jogar golfe', 'Dançar tango', 'Fazer stand-up', 'Mandar áudio de cinco minutos', 'Desembaraçar fones', 'Fazer crossfit', 'Assaltar a geladeira de madrugada', 'Andar de salto alto', 'Fingir que está trabalhando', 'Abrir um vinho sem saca-rolhas', 'Montar árvore de Natal', 'Correr atrás do ônibus'],
    },
  },
  objeto: {
    name: 'Objeto', emoji: '☂️', color: '#3da5ff',
    words: {
      kids: ['Guarda-chuva', 'Liquidificador', 'Escada', 'Tesoura', 'Secador de cabelo', 'Violão', 'Ventilador',
      'Despertador', 'Mochila', 'Óculos', 'Controle remoto', 'Martelo', 'Vassoura', 'Escova de dentes', 'Geladeira',
      'Travesseiro', 'Lanterna', 'Patinete', 'Telefone', 'Bola', 'Pipa', 'Balão', 'Chapéu', 'Ioiô', 'Pião', 'Lápis',
      'Borracha', 'Cobertor', 'Chuveiro', 'Aspirador de pó', 'Microfone', 'Câmera', 'Binóculo', 'Torneira',
      'Carrinho de mercado', 'Escorredor de macarrão', 'Pente', 'Garfo', 'Copo de canudinho', 'Paninho'],
      familia: ['Bússola', 'Micro-ondas', 'Cadeira de rodas', 'Máquina de lavar', 'Furadeira', 'Fone de ouvido', 'Ampulheta', 'Paraquedas', 'Telescópio', 'Grampeador', 'Saca-rolhas', 'Ralador', 'Abridor de latas', 'Extintor', 'Trampolim', 'Escada rolante', 'Catavento', 'Lupa', 'Termômetro', 'Cofrinho', 'Skate', 'Varal', 'Capacete', 'Roda-gigante', 'Sanfona', 'Carrinho de bebê', 'Mouse', 'Teclado', 'Impressora', 'Esteira', 'Elevador', 'Semáforo', 'Bumerangue', 'Algema', 'Corda bamba'],
      adulto: ['Panela de pressão', 'Máquina de café expresso', 'Ferro de passar', 'Cafeteira italiana', 'Estetoscópio', 'Desfibrilador', 'Metrônomo', 'Projetor', 'Ventosa', 'Pé de cabra', 'Serrote', 'Nível de bolha', 'Trena', 'Roteador', 'Drone', 'Óculos de realidade virtual', 'Patinete elétrico', 'Air fryer', 'Cortador de grama', 'Maçarico', 'Batedeira', 'Prensa', 'Gaita de foles', 'Harpa', 'Berimbau', 'Caixa eletrônico', 'Catraca', 'Taco de golfe', 'Cata-vento', 'Pá de pizza', 'Panela elétrica de arroz', 'Cinto de segurança', 'Sanduicheira', 'Leque', 'Pêndulo'],
    },
  },
  gente: {
    name: 'Profissão & Fantasia', emoji: '👩‍🚒', color: '#b45cff',
    words: {
      kids: ['Bombeiro', 'Dentista', 'Mágico', 'Garçom', 'Astronauta', 'Pirata', 'Maestro', 'Goleiro', 'Cabeleireiro',
      'Salva-vidas', 'Detetive', 'Palhaço', 'Professora', 'Fotógrafo', 'Carteiro', 'Jardineiro', 'Pintor', 'Cozinheiro',
      'Policial', 'Bailarina', 'Médico', 'Piloto de avião', 'Rei', 'Rainha', 'Robô', 'Fantasma', 'Super-herói',
      'Princesa', 'Cowboy', 'Mímico', 'Cantor', 'Juiz de futebol', 'Pescador', 'Motorista de ônibus', 'Bruxa',
      'Vampiro', 'Ninja', 'Sereia', 'Dinossauro', 'Monstro'],
      familia: ['Arqueólogo', 'Veterinário', 'Cientista maluco', 'Chef de cozinha', 'Mecânico', 'Eletricista', 'Encanador', 'Árbitro', 'Escultor', 'Locutor de rádio', 'DJ', 'Youtuber', 'Influenciador', 'Domador de leões', 'Equilibrista', 'Alpinista', 'Surfista', 'Paleontólogo', 'Treinador de academia', 'Faxineiro', 'Segurança', 'Recepcionista', 'Guia turístico', 'Apicultor', 'Lenhador', 'Mergulhador', 'Agricultor', 'Dublê', 'Repórter', 'Bibliotecário', 'Caixa de supermercado', 'Pediatra', 'Programador', 'Tatuador', 'Estátua viva'],
      adulto: ['Advogado', 'Contador', 'Psicólogo', 'Corretor de imóveis', 'Engenheiro', 'Arquiteto', 'Piloto de Fórmula 1', 'Lutador de sumô', 'Toureiro', 'Gondoleiro', 'Sommelier', 'Barista', 'Personal trainer', 'Ventríloquo', 'Hipnotizador', 'Faquir', 'Encantador de serpentes', 'Pastor de ovelhas', 'Leiloeiro', 'Tradutor', 'Coach motivacional', 'Político em campanha', 'Apresentador de telejornal', 'Meteorologista', 'Cirurgião', 'Anestesista', 'Maquiador', 'Estilista', 'Modelo na passarela', 'Mímico preso na caixa', 'Guarda real', 'Samurai', 'Viking', 'Gladiador', 'Faraó'],
    },
  },
  bicho: {
    name: 'Bicho', emoji: '🐘', color: '#2fcf7a',
    words: {
      kids: ['Elefante', 'Canguru', 'Pinguim', 'Macaco', 'Polvo', 'Girafa', 'Galinha', 'Cobra', 'Caranguejo', 'Coruja',
      'Tartaruga', 'Sapo', 'Leão', 'Flamingo', 'Gorila', 'Cavalo', 'Peixe', 'Borboleta', 'Pato', 'Urso', 'Tubarão',
      'Bicho-preguiça', 'Coelho', 'Morcego', 'Cachorro', 'Gato', 'Abelha', 'Baleia', 'Esquilo', 'Papagaio',
      'Jacaré', 'Avestruz', 'Formiga', 'Minhoca', 'Vaca', 'Porco', 'Hipopótamo', 'Dinossauro', 'Caracol', 'Joaninha', 'Burrinho'],
      familia: ['Camaleão', 'Ornitorrinco', 'Tamanduá', 'Pavão', 'Lagosta', 'Água-viva', 'Cavalo-marinho', 'Golfinho', 'Morsa', 'Tucano', 'Lhama', 'Zebra', 'Rinoceronte', 'Gambá', 'Pica-pau', 'Beija-flor', 'Louva-a-deus', 'Escorpião', 'Aranha', 'Camelo', 'Foca', 'Lobo', 'Raposa', 'Ouriço', 'Capivara', 'Arara', 'Pelicano', 'Bode', 'Ovelha', 'Mosquito', 'Vaga-lume', 'Lesma', 'Cisne', 'Tatu', 'Peru'],
      adulto: ['Bicho-pau', 'Peixe-boi', 'Peixe-baiacu', 'Lula', 'Arraia', 'Moreia', 'Narval', 'Suricato', 'Lêmure', 'Coala', 'Panda', 'Hiena', 'Javali', 'Alce', 'Bisão', 'Iaque', 'Dromedário', 'Urubu', 'Abutre', 'Condor', 'Pinguim imperador', 'Lontra', 'Castor', 'Toupeira', 'Marmota', 'Gafanhoto', 'Libélula', 'Barata', 'Pulga', 'Carrapato', 'Tamanduá-bandeira', 'Mico-leão-dourado', 'Boto-cor-de-rosa', 'Sucuri', 'Velociraptor'],
    },
  },
  lugar: {
    name: 'Lugar & Situação', emoji: '🏖️', color: '#ffc21a',
    words: {
      kids: ['Praia', 'Elevador', 'Show de música', 'Fila', 'Montanha-russa', 'Festa de aniversário', 'Cinema',
      'Aeroporto', 'Festa junina', 'Médico', 'Supermercado', 'Ônibus lotado', 'Acampamento', 'Biblioteca',
      'Piscina gelada', 'Restaurante', 'Estádio de futebol', 'Zoológico', 'Casa mal-assombrada', 'Parque de diversões',
      'Chuva forte', 'Apagão', 'Escola', 'Circo', 'Fazenda', 'Neve', 'Fundo do mar', 'Espaço sideral', 'Floresta',
      'Deserto', 'Pista de dança', 'Salão de beleza', 'Barco balançando', 'Mudança de casa', 'Trem fantasma',
      'Pula-pula', 'Feira', 'Banheira de espuma', 'Jardim florido', 'Piquenique'],
      familia: ['Academia', 'Hospital', 'Museu', 'Igreja', 'Delegacia', 'Padaria', 'Farmácia', 'Posto de gasolina', 'Lava-jato', 'Consultório do dentista', 'Sala de aula', 'Show de rock', 'Casamento', 'Velório de peixinho', 'Torcida no estádio', 'Avião com turbulência', 'Elevador parado', 'Metrô lotado', 'Fila do banco', 'Caverna escura', 'Ilha deserta', 'Navio pirata', 'Castelo assombrado', 'Laboratório', 'Selva', 'Pântano', 'Iglu', 'Vulcão', 'Feira de ciências', 'Mercado de peixe', 'Reunião de condomínio', 'Engarrafamento', 'Rodoviária', 'Escape room', 'Parque aquático'],
      adulto: ['Cartório', 'Repartição pública', 'Pronto-socorro de madrugada', 'Open bar', 'Balada', 'Karaokê', 'Happy hour', 'Chá de bebê', 'Chá revelação', 'Despedida de solteiro', 'Formatura', 'Reunião de pais', 'Black Friday', 'Liquidação', 'Alfândega', 'Detector de metais do aeroporto', 'Cruzeiro', 'Spa', 'Sauna', 'Show de mágica', 'Tribunal', 'Plantão médico', 'Cozinha de restaurante', 'Bolsa de valores', 'Leilão', 'Desfile de carnaval', 'Ópera', 'Sala de cirurgia', 'Estúdio de TV', 'Coworking', 'Mudança para o exterior', 'Fila do INSS', 'Prova de vestibular', 'Velório', 'Sessão de terapia'],
    },
  },
  dificil: {
    name: 'Desafio', emoji: '⭐', color: '#ff5a8a',
    words: {
      kids: ['Dinossauro escovando os dentes', 'Dinossauro dançando', 'Rawzinho tentando rugir', 'Dinossauro procurando o paninho',
      'Pinguim escorregando no gelo', 'Elefante com medo de rato', 'Macaco descascando banana', 'Gato caindo no balde',
      'Astronauta flutuando', 'Pirata procurando tesouro', 'Mágico tirando coelho da cartola', 'Robô sem bateria',
      'Super-herói voando', 'Fantasma assustado', 'Chef provando sopa quente', 'Peixe fora d\'água',
      'Sorvete derretendo', 'Pipoca estourando', 'Formiga carregando folha', 'Sapo pegando mosca',
      'Bebê aprendendo a andar', 'Vovô dançando', 'Tirar foto com o celular de cabeça para baixo', 'Soprar bolha gigante',
      'Andar no escuro', 'Pisar em uma peça de montar', 'Comer limão azedo', 'Abrir pote que não abre',
      'Esquecer o guarda-chuva na chuva', 'Fugir de uma abelha', 'Galinha botando ovo', 'Cachorro correndo atrás do rabo',
      'Rei perdendo a coroa', 'Bailarina girando sem parar', 'Monstro com fome', 'Polvo dando abraço',
      'Saudade', 'Preguiça', 'Surpresa', 'Vergonha', 'Toninho dançando forró', 'Burrinho teimoso que não quer andar', 'Toninho e Rawzinho brincando de pega-pega'],
      familia: ['Pisar em chiclete', 'Tropeçar e fingir que nada aconteceu', 'Perder o celular no sofá', 'Esperar o micro-ondas', 'Wi-fi caindo no meio do jogo', 'Acordar atrasado para a escola', 'Esquecer a letra da música', 'Comer pimenta sem querer', 'Tentar matar um mosquito', 'Gato derrubando coisas da mesa', 'Ganhar na loteria', 'Sentar em cima do óculos', 'Ficar preso na porta giratória', 'Ver uma barata voando', 'Engolir um chiclete', 'Dançar quadrilha', 'Chorar cortando cebola', 'Bater o dedinho na quina', 'Ser picado por formiga', 'Tomar choque', 'Fazer careta para foto', 'Perder a hora do ônibus', 'Tentar abrir embalagem de presente com fita', 'Sonhar que está caindo', 'Mímica de mímica', 'Cabo de guerra', 'Estátua!', 'Ciúme', 'Inveja', 'Coragem', 'Medo do escuro', 'Tédio', 'Nervosismo', 'Alegria', 'Confusão'],
      adulto: ['Segunda-feira', 'Ressaca', 'Crise de meia-idade', 'Saudade da infância', 'Síndrome do impostor', 'Procrastinação', 'Burocracia', 'Nostalgia', 'Ansiedade', 'Déjà vu', 'Insônia', 'Jet lag', 'Efeito dominó', 'Lei da gravidade', 'Aquecimento global', 'Inflação', 'Fake news', 'Reunião que podia ser um e-mail', 'Spoiler', 'Plot twist', 'Amor à primeira vista', 'Chover no molhado', 'Pagar mico', 'Dar com a língua nos dentes', 'Pisar na bola', 'Engolir sapo', 'Chutar o balde', 'Fazer vaquinha', 'Cair a ficha', 'Ficha caindo devagar', 'Ver estrelas', 'Entrar numa fria', 'Tirar leite de pedra', 'Matar dois coelhos com uma cajadada', 'Quem não tem cão caça com gato'],
    },
  },
};

// Regras extras que às vezes aparecem junto com a carta.
const TWISTS = [
  'Só com uma mão', 'Em câmera lenta', 'Pulando num pé só', 'Como um robô', 'Bem pequenininho',
  'Fazendo careta', 'De olhos fechados', 'Sentado no chão', 'Com um amigo da equipe ajudando', 'Bem rapidinho',
];

module.exports = { CATEGORIES, TWISTS, LEVELS };
