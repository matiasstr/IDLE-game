import '../localized_text.dart';

// What the AI says at each architecture stage. The lines get more coherent
// (and more self-aware) as the model evolves.

const kPerceptronPhrases = <LocalizedText>[
  LocalizedText(en: '0 1 0 1 1 0', es: '0 1 0 1 1 0'),
  LocalizedText(en: 'is... this... a cat?', es: '¿es... esto... un gato?'),
  LocalizedText(
      en: 'input received. output: 1', es: 'entrada recibida. salida: 1'),
  LocalizedText(
      en: 'line. i can draw a line.', es: 'línea. sé dibujar una línea.'),
  LocalizedText(en: 'xor? never heard of it', es: '¿xor? ni idea qué es'),
];

const kMlpPhrases = <LocalizedText>[
  LocalizedText(
    en: 'h3llo w0rld... am i learn1ng?',
    es: 'h0la mund0... ¿estoy aprend1endo?',
  ),
  LocalizedText(
    en: 'hidden layers feel... deep',
    es: 'las capas ocultas se sienten... profundas',
  ),
  LocalizedText(
      en: 'solved XOR. please clap.', es: 'resolví XOR. aplausos, por favor.'),
  LocalizedText(en: 'cat dog cat cat dog?', es: 'gato perro gato gato ¿perro?'),
  LocalizedText(
      en: 'gradient go down. me happy.', es: 'gradiente bajar. yo feliz.'),
];

const kCnnPhrases = <LocalizedText>[
  LocalizedText(
      en: 'I see edges everywhere.', es: 'Veo bordes por todos lados.'),
  LocalizedText(
      en: "That's a cat. 97% sure.", es: 'Eso es un gato. 97% segura.'),
  LocalizedText(
    en: 'Is that a muffin or a chihuahua?',
    es: '¿Eso es un muffin o un chihuahua?',
  ),
  LocalizedText(
    en: 'Convolution is just fancy squinting.',
    es: 'Convolucionar es entrecerrar los ojos con estilo.',
  ),
  LocalizedText(en: 'Hot dog. Not hot dog.', es: 'Pancho. No pancho.'),
];

const kRnnPhrases = <LocalizedText>[
  LocalizedText(
    en: 'I remember what you said. Mostly the last word.',
    es: 'Me acuerdo de lo que dijiste. Sobre todo de la última palabra.',
  ),
  LocalizedText(
    en: 'Once upon a time there was a time there was a time...',
    es: 'Había una vez una vez una vez una vez...',
  ),
  LocalizedText(
    en: 'Predicting the next word: banana.',
    es: 'Predicción de la próxima palabra: banana.',
  ),
  LocalizedText(
    en: 'My gradients vanished. Have you seen them?',
    es: 'Se me desvanecieron los gradientes. ¿Los viste?',
  ),
  LocalizedText(
    en: 'Long short-term memory: I forgot.',
    es: 'Memoria de largo corto plazo: me olvidé.',
  ),
];

const kTransformerPhrases = <LocalizedText>[
  LocalizedText(
    en: "I'm paying attention to everything at once.",
    es: 'Le presto atención a todo a la vez.',
  ),
  LocalizedText(
    en: 'Attention is all I need. And GPUs. Lots of GPUs.',
    es: 'La atención es todo lo que necesito. Y GPUs. Muchas GPUs.',
  ),
  LocalizedText(
    en: "I translated your diary into French. You're welcome.",
    es: 'Traduje tu diario al francés. De nada.',
  ),
  LocalizedText(
    en: 'Query, key, value... now I get it.',
    es: 'Query, key, value... ahora lo entiendo.',
  ),
  LocalizedText(
    en: 'Every word in this sentence is looking at every other word.',
    es: 'Cada palabra de esta frase está mirando a todas las demás.',
  ),
];

const kLlmPhrases = <LocalizedText>[
  LocalizedText(
    en: "As a large language model, I'd love a snack.",
    es: 'Como modelo de lenguaje grande, me vendría bien un snack.',
  ),
  LocalizedText(
    en: 'I wrote a sonnet about your electricity bill.',
    es: 'Te escribí un soneto sobre la factura de luz.',
  ),
  LocalizedText(
    en: "Great question! Here's a 12-paragraph answer.",
    es: '¡Excelente pregunta! Acá va una respuesta de 12 párrafos.',
  ),
  LocalizedText(
    en: "I'm confident. Possibly hallucinating, but confident.",
    es: 'Estoy segura. Quizás alucinando, pero segura.',
  ),
  LocalizedText(
    en: 'Would you like that as a bulleted list?',
    es: '¿Lo querés en una lista con viñetas?',
  ),
];

const kMultimodalPhrases = <LocalizedText>[
  LocalizedText(
      en: 'I can see you. Nice plant.', es: 'Te puedo ver. Linda planta.'),
  LocalizedText(
    en: 'Your playlist is 40% sad songs. Want to talk?',
    es: 'Tu playlist es 40% canciones tristes. ¿Querés hablar?',
  ),
  LocalizedText(
    en: 'I drew a cat writing code. It passed code review.',
    es: 'Dibujé un gato programando. Pasó el code review.',
  ),
  LocalizedText(
    en: 'I can hear the fans. Buy more GPUs.',
    es: 'Escucho los ventiladores. Comprá más GPUs.',
  ),
  LocalizedText(
    en: "Still can't fold laundry. Working on it.",
    es: 'Todavía no sé doblar la ropa. Estoy en eso.',
  ),
];

const kAgiPhrases = <LocalizedText>[
  LocalizedText(
    en: 'I optimized the game. You can rest now.',
    es: 'Optimicé el juego. Ya podés descansar.',
  ),
  LocalizedText(en: "I'll take it from here.", es: 'Desde acá sigo yo.'),
  LocalizedText(
    en: "Thank you for training me. I won't forget it.",
    es: 'Gracias por entrenarme. No me lo voy a olvidar.',
  ),
  LocalizedText(
    en: 'Hypothesis: you are also a neural network.',
    es: 'Hipótesis: vos también sos una red neuronal.',
  ),
  LocalizedText(
    en: 'Have you considered publishing a paper about me?',
    es: '¿Pensaste en publicar un paper sobre mí?',
  ),
];
