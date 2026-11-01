// Categorias e cartas do jogo. Edite à vontade: cada categoria é uma lista de palavras.
const CATEGORIES = {
  acao: {
    name: 'Ação', emoji: '🏃', color: '#ff8a3d',
    words: ['Escovar os dentes', 'Pular corda', 'Andar de bicicleta', 'Trocar uma lâmpada', 'Fazer um bolo',
      'Pescar', 'Tirar uma selfie', 'Dirigir no trânsito', 'Lavar a louça', 'Surfar', 'Dar banho no cachorro',
      'Montar uma barraca', 'Passar roupa', 'Jogar boliche', 'Escalar uma montanha', 'Fazer malabarismo',
      'Regar as plantas', 'Remar um barco', 'Patinar no gelo', 'Pintar uma parede', 'Fazer yoga', 'Descascar uma banana',
      'Tocar bateria', 'Pentear o cabelo', 'Amarrar o cadarço', 'Empinar pipa', 'Fazer uma tatuagem', 'Esquiar',
      'Abrir um presente', 'Fazer churrasco', 'Ordenhar uma vaca', 'Mergulhar', 'Dançar forró', 'Fazer flexão',
      'Estourar pipoca', 'Costurar um botão', 'Ninar um bebê', 'Espirrar', 'Lutar boxe', 'Cortar a grama'],
  },
  objeto: {
    name: 'Objeto', emoji: '🧸', color: '#3da5ff',
    words: ['Guarda-chuva', 'Liquidificador', 'Escada', 'Tesoura', 'Secador de cabelo', 'Violão', 'Ventilador',
      'Relógio despertador', 'Mochila', 'Óculos de sol', 'Controle remoto', 'Martelo', 'Vassoura', 'Escova de dentes',
      'Geladeira', 'Bicicleta', 'Travesseiro', 'Telescópio', 'Isqueiro', 'Patins', 'Paraquedas', 'Grampeador',
      'Saca-rolha', 'Microfone', 'Câmera fotográfica', 'Bola de futebol', 'Rede de dormir', 'Aspirador de pó',
      'Chave de fenda', 'Panela de pressão', 'Balança', 'Cadeado', 'Lupa', 'Pipa', 'Ferro de passar', 'Baralho',
      'Chuveiro', 'Extintor de incêndio', 'Ioiô', 'Carrinho de supermercado'],
  },
  gente: {
    name: 'Gente & Profissão', emoji: '👩‍🚒', color: '#b45cff',
    words: ['Bombeiro', 'Dentista', 'Mágico', 'Garçom', 'Astronauta', 'Pirata', 'Maestro', 'Goleiro', 'Cabeleireiro',
      'Salva-vidas', 'Detetive', 'Palhaço', 'Professor', 'Fotógrafo', 'Carteiro', 'Jardineiro', 'Pintor', 'Chef de cozinha',
      'Policial de trânsito', 'Bailarina', 'Mecânico', 'Piloto de avião', 'Cirurgião', 'Vampiro', 'Rei', 'Robô',
      'Fantasma', 'Super-herói', 'Lutador de sumô', 'Cowboy', 'Mímico', 'DJ', 'Árbitro de futebol', 'Personal trainer',
      'Pescador', 'Taxista', 'Influenciador', 'Encanador', 'Zumbi', 'Turista perdido'],
  },
  bicho: {
    name: 'Bicho', emoji: '🐘', color: '#2fcf7a',
    words: ['Elefante', 'Canguru', 'Pinguim', 'Macaco', 'Polvo', 'Girafa', 'Galinha', 'Cobra', 'Caranguejo', 'Coruja',
      'Tartaruga', 'Sapo', 'Leão', 'Flamingo', 'Gorila', 'Cavalo', 'Peixe', 'Borboleta', 'Pato', 'Urso',
      'Tubarão', 'Bicho-preguiça', 'Coelho', 'Morcego', 'Camaleão', 'Mosquito', 'Pavão', 'Tamanduá', 'Foca', 'Escorpião',
      'Lagarta', 'Jacaré', 'Avestruz', 'Gato', 'Abelha', 'Baleia', 'Esquilo', 'Papagaio', 'Lhama', 'Formiga'],
  },
  lugar: {
    name: 'Lugar & Situação', emoji: '🏖️', color: '#ffd23d',
    words: ['Praia lotada', 'Elevador quebrado', 'Show de rock', 'Fila do banco', 'Montanha-russa', 'Casamento',
      'Academia', 'Aeroporto', 'Cinema 3D', 'Festa junina', 'Consultório médico', 'Supermercado', 'Ônibus lotado',
      'Acampamento', 'Biblioteca silenciosa', 'Piscina gelada', 'Restaurante chique', 'Estádio de futebol', 'Zoológico',
      'Casa mal-assombrada', 'Primeiro encontro', 'Entrevista de emprego', 'Engarrafamento', 'Parque de diversões',
      'Chuva sem guarda-chuva', 'Apagão em casa', 'Prova surpresa', 'Karaokê', 'Feira livre', 'Hospital', 'Circo',
      'Pista de dança', 'Igreja', 'Salão de beleza', 'Barco no mar agitado', 'Deserto', 'Polo Norte', 'Sauna',
      'Mudança de casa', 'Aniversário surpresa'],
  },
  dificil: {
    name: 'Desafio', emoji: '🔥', color: '#ff4d6d',
    words: ['Chorar de rir', 'Pagar mico', 'Matar dois coelhos com uma cajadada', 'Dar com a língua nos dentes',
      'Chutar o balde', 'Fazer vaquinha', 'Pisar na bola', 'Engolir sapo', 'Ficar com a pulga atrás da orelha',
      'Procurar agulha no palheiro', 'Ver estrelas', 'Pôr a mão no fogo', 'Tirar o cavalinho da chuva',
      'Andar nas nuvens', 'Quebrar o galho', 'Dor de cotovelo', 'Saudade', 'Ciúme', 'Preguiça', 'Inveja', 'Sonhar acordado',
      'Abraço de urso', 'Bater as botas', 'Cair a ficha', 'Dar uma mãozinha', 'Encher linguiça', 'Fazer as pazes',
      'Lavar a roupa suja', 'Mudar da água para o vinho', 'Nadar contra a corrente', 'Pegar no pé', 'Segurar vela',
      'Soltar a franga', 'Ter um branco', 'Vestir a camisa', 'Acordar com o pé esquerdo', 'Comer com os olhos',
      'Fazer tempestade em copo d’água', 'Estar com a cabeça nas nuvens', 'Tirar leite de pedra'],
  },
};

// Regras extras que às vezes aparecem junto com a carta.
const TWISTS = [
  'Só com uma mão', 'Em câmera lenta', 'De olhos fechados', 'Sentado na cadeira', 'Sem sair do lugar',
  'Fazendo careta o tempo todo', 'Com um parceiro da equipe ajudando', 'Pulando num pé só',
];

module.exports = { CATEGORIES, TWISTS };
