// Categorias e cartas do Mimicaço da Turma do Rawzinho. Edite à vontade: cada categoria é uma lista de palavras.
// Pensadas para crianças: coisas do dia a dia, bichos, brincadeiras e situações engraçadas.
const CATEGORIES = {
  acao: {
    name: 'Ação', emoji: '🏃', color: '#ff8a3d',
    words: ['Escovar os dentes', 'Pular corda', 'Andar de bicicleta', 'Tomar banho', 'Fazer um bolo', 'Pescar',
      'Tirar uma foto', 'Dirigir um carro', 'Lavar a louça', 'Nadar', 'Dar banho no cachorro', 'Soprar velinhas',
      'Jogar bola', 'Chutar a bola', 'Pintar um quadro', 'Plantar uma flor', 'Remar um barco', 'Andar de patins',
      'Comer pipoca', 'Fazer yoga', 'Descascar uma banana', 'Tocar bateria', 'Pentear o cabelo', 'Amarrar o tênis',
      'Soltar pipa', 'Abrir um presente', 'Dormir', 'Acordar com preguiça', 'Espirrar', 'Fazer bolinhas de sabão',
      'Tomar sorvete', 'Brincar de esconde-esconde', 'Pular na cama', 'Varrer o chão', 'Ler um livro', 'Andar na chuva',
      'Subir uma escada', 'Escorregar no escorregador', 'Balançar no balanço', 'Fazer um boneco de neve'],
  },
  objeto: {
    name: 'Objeto', emoji: '☂️', color: '#3da5ff',
    words: ['Guarda-chuva', 'Liquidificador', 'Escada', 'Tesoura', 'Secador de cabelo', 'Violão', 'Ventilador',
      'Despertador', 'Mochila', 'Óculos', 'Controle remoto', 'Martelo', 'Vassoura', 'Escova de dentes', 'Geladeira',
      'Travesseiro', 'Lanterna', 'Patinete', 'Telefone', 'Bola', 'Pipa', 'Balão', 'Chapéu', 'Ioiô', 'Pião', 'Lápis',
      'Borracha', 'Cobertor', 'Chuveiro', 'Aspirador de pó', 'Microfone', 'Câmera', 'Binóculo', 'Torneira',
      'Carrinho de mercado', 'Escorredor de macarrão', 'Pente', 'Garfo', 'Copo de canudinho', 'Paninho'],
  },
  gente: {
    name: 'Profissão & Fantasia', emoji: '👩‍🚒', color: '#b45cff',
    words: ['Bombeiro', 'Dentista', 'Mágico', 'Garçom', 'Astronauta', 'Pirata', 'Maestro', 'Goleiro', 'Cabeleireiro',
      'Salva-vidas', 'Detetive', 'Palhaço', 'Professora', 'Fotógrafo', 'Carteiro', 'Jardineiro', 'Pintor', 'Cozinheiro',
      'Policial', 'Bailarina', 'Médico', 'Piloto de avião', 'Rei', 'Rainha', 'Robô', 'Fantasma', 'Super-herói',
      'Princesa', 'Cowboy', 'Mímico', 'Cantor', 'Juiz de futebol', 'Pescador', 'Motorista de ônibus', 'Bruxa',
      'Vampiro', 'Ninja', 'Sereia', 'Dinossauro', 'Monstro'],
  },
  bicho: {
    name: 'Bicho', emoji: '🐘', color: '#2fcf7a',
    words: ['Elefante', 'Canguru', 'Pinguim', 'Macaco', 'Polvo', 'Girafa', 'Galinha', 'Cobra', 'Caranguejo', 'Coruja',
      'Tartaruga', 'Sapo', 'Leão', 'Flamingo', 'Gorila', 'Cavalo', 'Peixe', 'Borboleta', 'Pato', 'Urso', 'Tubarão',
      'Bicho-preguiça', 'Coelho', 'Morcego', 'Cachorro', 'Gato', 'Abelha', 'Baleia', 'Esquilo', 'Papagaio',
      'Jacaré', 'Avestruz', 'Formiga', 'Minhoca', 'Vaca', 'Porco', 'Hipopótamo', 'Dinossauro', 'Caracol', 'Joaninha'],
  },
  lugar: {
    name: 'Lugar & Situação', emoji: '🏖️', color: '#ffc21a',
    words: ['Praia', 'Elevador', 'Show de música', 'Fila', 'Montanha-russa', 'Festa de aniversário', 'Cinema',
      'Aeroporto', 'Festa junina', 'Médico', 'Supermercado', 'Ônibus lotado', 'Acampamento', 'Biblioteca',
      'Piscina gelada', 'Restaurante', 'Estádio de futebol', 'Zoológico', 'Casa mal-assombrada', 'Parque de diversões',
      'Chuva forte', 'Apagão', 'Escola', 'Circo', 'Fazenda', 'Neve', 'Fundo do mar', 'Espaço sideral', 'Floresta',
      'Deserto', 'Pista de dança', 'Salão de beleza', 'Barco balançando', 'Mudança de casa', 'Trem fantasma',
      'Pula-pula', 'Feira', 'Banheira de espuma', 'Jardim florido', 'Piquenique'],
  },
  dificil: {
    name: 'Desafio', emoji: '⭐', color: '#ff5a8a',
    words: ['Dinossauro escovando os dentes', 'Dinossauro dançando', 'Rawzinho tentando rugir', 'Dinossauro procurando o paninho',
      'Pinguim escorregando no gelo', 'Elefante com medo de rato', 'Macaco descascando banana', 'Gato caindo no balde',
      'Astronauta flutuando', 'Pirata procurando tesouro', 'Mágico tirando coelho da cartola', 'Robô sem bateria',
      'Super-herói voando', 'Fantasma assustado', 'Chef provando sopa quente', 'Peixe fora d\'água',
      'Sorvete derretendo', 'Pipoca estourando', 'Formiga carregando folha', 'Sapo pegando mosca',
      'Bebê aprendendo a andar', 'Vovô dançando', 'Tirar foto com o celular de cabeça para baixo', 'Soprar bolha gigante',
      'Andar no escuro', 'Pisar em uma peça de montar', 'Comer limão azedo', 'Abrir pote que não abre',
      'Esquecer o guarda-chuva na chuva', 'Fugir de uma abelha', 'Galinha botando ovo', 'Cachorro correndo atrás do rabo',
      'Rei perdendo a coroa', 'Bailarina girando sem parar', 'Monstro com fome', 'Polvo dando abraço',
      'Saudade', 'Preguiça', 'Surpresa', 'Vergonha'],
  },
};

// Regras extras que às vezes aparecem junto com a carta.
const TWISTS = [
  'Só com uma mão', 'Em câmera lenta', 'Pulando num pé só', 'Como um robô', 'Bem pequenininho',
  'Fazendo careta', 'De olhos fechados', 'Sentado no chão', 'Com um amigo da equipe ajudando', 'Bem rapidinho',
];

module.exports = { CATEGORIES, TWISTS };
