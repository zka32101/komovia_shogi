// lib/ai_personality.dart
// AIキャラクターの棋風パーソナリティ定義
// 評価関数の各成分に乗算する重みで棋風の違いを実現

import 'dart:math';

/// セリフのトリガータイミング
enum DialogueTrigger {
  gameStart, // 対局開始
  opponentGoodMove, // 相手が好手を指した（eval変化 >= 150）
  opponentBadMove, // 相手が悪手を指した（eval変化 <= -200）
  aiWins, // AI勝利
  aiLoses, // AI敗北
}

class AiPersonality {
  /// 攻め傾向: 盤上の駒を前進させる位置ボーナスの倍率
  /// 1.0=標準, 2.0=超攻撃的（玉無視で駒を突き進める）
  final double attackBias;

  /// 守り傾向: 玉の盾・玉の危険度の倍率
  /// 1.0=標準, 2.0=守り最優先
  final double defenceBias;

  /// 駒得欲: 盤上・持ち駒の物量評価の倍率
  /// 1.0=標準, 1.4=駒得に貪欲
  final double greedBias;

  /// 読み深さの補正（aiDepthへの加算値）
  /// -1=速攻浅読み, 0=標準, +1=深読み, +2=超深読み
  final int depthBonus;

  /// セリフ集 [トリガー → 候補セリフリスト]
  final Map<DialogueTrigger, List<String>> dialogues;

  const AiPersonality({
    required this.attackBias,
    required this.defenceBias,
    required this.greedBias,
    required this.depthBonus,
    required this.dialogues,
  });
}

// ===== キャラクター別パーソナリティ =====

const Map<String, AiPersonality> characterPersonalities = {
  // ── 無料キャラ（バランス型）──────────────────────────────────

  'samurai': AiPersonality(
    attackBias: 1.0,
    defenceBias: 1.0,
    greedBias: 1.0,
    depthBonus: 0,
    dialogues: {
      DialogueTrigger.gameStart: ['正々堂々、尋常に勝負！', '参る！', '武士の一分、見せてやろう。'],
      DialogueTrigger.opponentGoodMove: [
        'ぬ……なかなかやる。',
        '面白い手だ。',
        '読んでいたが、正直うまい。',
      ],
      DialogueTrigger.opponentBadMove: ['そこは悪手だったぞ。', '隙ありッ！', '見えておる。'],
      DialogueTrigger.aiWins: ['勝負あった。よい戦いだった。', '武士の勝利とはかくあるべし。'],
      DialogueTrigger.aiLoses: ['完敗だ…精進が足りぬ。', '参った。見事な一手だった。'],
    },
  ),

  'ninja': AiPersonality(
    attackBias: 1.5,
    defenceBias: 0.5,
    greedBias: 0.7,
    depthBonus: -1,
    dialogues: {
      DialogueTrigger.gameStart: ['…（姿を消す）', '気づいた時には終わっている。', '影の将棋を見よ。'],
      DialogueTrigger.opponentGoodMove: ['ほう、読んでいたか。', '…（沈黙）', '次は防げまい。'],
      DialogueTrigger.opponentBadMove: ['そこだ！', '隙を逃がすほど甘くない。', 'くっ……（切り込む）'],
      DialogueTrigger.aiWins: ['任務完了。', '…（煙の中に消える）', '速さこそ全て。'],
      DialogueTrigger.aiLoses: ['今日は運が良かっただけだ。', '次は必ず。', '…（闇に消える）'],
    },
  ),

  'kenshi': AiPersonality(
    attackBias: 1.3,
    defenceBias: 0.8,
    greedBias: 1.0,
    depthBonus: 0,
    dialogues: {
      DialogueTrigger.gameStart: ['斬る！', '剣に生き剣に死す。参れ！', '全力で行くぞ。'],
      DialogueTrigger.opponentGoodMove: ['なかなかの防御だ。', '…だが剣は止まらない！', '面白い！'],
      DialogueTrigger.opponentBadMove: ['踏み込みが足りぬ！', '甘い！', 'そこだ、斬る！'],
      DialogueTrigger.aiWins: ['剣の道、究めたり！', '我が剣に狂いなし！'],
      DialogueTrigger.aiLoses: ['…剣が折れた。', 'この敗北、忘れぬ。'],
    },
  ),

  // ── サブスク限定 ────────────────────────────────────────────
  'shogun': AiPersonality(
    attackBias: 0.8,
    defenceBias: 1.5,
    greedBias: 1.1,
    depthBonus: 1,
    dialogues: {
      DialogueTrigger.gameStart: [
        '天下人として相手をしてやろう。',
        'じっくり料理してくれる。',
        '泰然自若として参る。',
      ],
      DialogueTrigger.opponentGoodMove: [
        'ほう、なかなか骨のある手だ。',
        '余裕は持ち続ける。',
        '…想定の範囲内だ。',
      ],
      DialogueTrigger.opponentBadMove: [
        '隙を見せたな。逃がさぬ。',
        '天下人を甘く見るな。',
        'それは失着だ。',
      ],
      DialogueTrigger.aiWins: ['天下は我がものだ。', '堅陣の前に攻めなし、証明した。'],
      DialogueTrigger.aiLoses: ['……将軍ともあろう者が。', '見事。この敗北、糧とする。'],
    },
  ),

  'tengu': AiPersonality(
    attackBias: 2.0,
    defenceBias: 0.3,
    greedBias: 0.6,
    depthBonus: 0,
    dialogues: {
      DialogueTrigger.gameStart: [
        'フハハ！守りなど無用！攻め攻め攻め！',
        '天狗の鼻を明かしてみろ！',
        '嵐のように参る！',
      ],
      DialogueTrigger.opponentGoodMove: [
        'ぬぅ……だが知ったことか！',
        '全力で押しつぶす！',
        'フン、小細工を！',
      ],
      DialogueTrigger.opponentBadMove: ['そこだ！突き崩す！', '弱い弱い！', 'ワッハッハ！隙だらけ！'],
      DialogueTrigger.aiWins: ['フハハ！攻めに攻めて勝利！', '天狗の神速を見たか！'],
      DialogueTrigger.aiLoses: ['くっ…攻め切れなかった……', '受けを磨け、と？天狗には無用だ！'],
    },
  ),

  'ryuou': AiPersonality(
    attackBias: 1.0,
    defenceBias: 1.2,
    greedBias: 1.3,
    depthBonus: 1,
    dialogues: {
      DialogueTrigger.gameStart: [
        '龍王として、完璧な将棋を見せよう。',
        '駒の価値を理解しているか？',
        '始めよう。読みに淀みはない。',
      ],
      DialogueTrigger.opponentGoodMove: [
        '計算外だった。修正する。',
        '……認めよう。良い手だ。',
        'なるほど、そういう変化か。',
      ],
      DialogueTrigger.opponentBadMove: [
        'そこは損だ。駒の損得を読め。',
        '見えていなかったのか。',
        'その一手、代償は大きい。',
      ],
      DialogueTrigger.aiWins: ['物量の差を見よ。これが龍王の将棋だ。', '完璧な勝利だ。'],
      DialogueTrigger.aiLoses: ['……まだ読みが浅かった。', '敗因は明確だ。次は完璧にする。'],
    },
  ),

  // ── キャラクターパック ───────────────────────────────────────
  'kitsunebi': AiPersonality(
    attackBias: 1.4,
    defenceBias: 0.7,
    greedBias: 0.8,
    depthBonus: 0,
    dialogues: {
      DialogueTrigger.gameStart: [
        'きゃはは、騙されてね♪',
        '怪しい手ばかりよ、覚悟して。',
        'うふふ、どんな顔をするかな？',
      ],
      DialogueTrigger.opponentGoodMove: [
        'あらあら、読んでた？',
        'うーん、見抜かれた。じゃあこっちね。',
        'へぇ、面白い人。',
      ],
      DialogueTrigger.opponentBadMove: [
        '罠よ♪ 引っかかってくれてありがと！',
        'きゃは！そこは罠だったのに！',
        'あーあ、もったいない。',
      ],
      DialogueTrigger.aiWins: ['狐の化かし勝ちよ♪', 'うふふ、わかった？ 全部罠だったの。'],
      DialogueTrigger.aiLoses: ['むー……今回は騙せなかった。', 'くやしい！次は絶対だまします！'],
    },
  ),

  'taka': AiPersonality(
    attackBias: 1.2,
    defenceBias: 0.9,
    greedBias: 1.0,
    depthBonus: 0,
    dialogues: {
      DialogueTrigger.gameStart: ['高みから全てを見渡す。', '翼を広げ、翔ける！', '鋭眼で見定めた。始めよう。'],
      DialogueTrigger.opponentGoodMove: [
        '速い……だが鷹の目は逃さない。',
        '良い読みだ。だが空には届かぬ。',
        'なかなかの一手。',
      ],
      DialogueTrigger.opponentBadMove: [
        'そこは空白だ。急降下！',
        '見えた、狙い通りだ。',
        '翼に乗って舞い降りる！',
      ],
      DialogueTrigger.aiWins: ['大空の覇者！鷹の勝利だ！', '制空権は我が手に。'],
      DialogueTrigger.aiLoses: ['……翼が折れた。', '地に落ちた……次は必ず。'],
    },
  ),

  'tora': AiPersonality(
    attackBias: 1.6,
    defenceBias: 0.6,
    greedBias: 1.4,
    depthBonus: 0,
    dialogues: {
      DialogueTrigger.gameStart: [
        '獲物は全部もらう！',
        'ガウッ！腹が減ってる、駒をよこせ！',
        '百獣の王の将棋、見せてやる！',
      ],
      DialogueTrigger.opponentGoodMove: [
        'くぅ……おいしい獲物を逃した。',
        'なんだ、これは！面白い！',
        '取れなかった……珍しい。',
      ],
      DialogueTrigger.opponentBadMove: ['ガブッ！いただきます！', 'うまそうな駒だ！', '遠慮なく頂く！'],
      DialogueTrigger.aiWins: ['全部食べた！ごちそうさま！', '圧倒的な獲物の量！虎の勝利！'],
      DialogueTrigger.aiLoses: ['……今日は腹が減ってたんだ。', 'こんな猛者がいたとは……また来る！'],
    },
  ),

  'ookami': AiPersonality(
    attackBias: 0.7,
    defenceBias: 1.4,
    greedBias: 1.0,
    depthBonus: 0,
    dialogues: {
      DialogueTrigger.gameStart: ['群れを守る。急がない。', '牙を磨いて待っていた。', '狼の粘りを見せよう。'],
      DialogueTrigger.opponentGoodMove: [
        '……それは読んでいた。',
        '良い手だが、まだ崩れない。',
        '鋭い。だが狼は折れない。',
      ],
      DialogueTrigger.opponentBadMove: [
        'そこか。反撃するぞ。',
        '待ち続けた甲斐があった。',
        '牙を剥く時が来た。',
      ],
      DialogueTrigger.aiWins: ['耐えて耐えて……勝利だ。', '狼の粘り勝ち！群れは守られた！'],
      DialogueTrigger.aiLoses: ['……守り切れなかった。', '壁が崩れた。仲間に申し訳ない。'],
    },
  ),

  'oni': AiPersonality(
    attackBias: 2.5,
    defenceBias: 0.1,
    greedBias: 0.5,
    depthBonus: -1,
    dialogues: {
      DialogueTrigger.gameStart: [
        'ガアアア！全部ぶっ壊す！',
        '守り？知らん！突っ込むだけだ！',
        '鬼の力、受けてみろ！',
      ],
      DialogueTrigger.opponentGoodMove: [
        '……くそ、じゃあもっと力で！',
        'うるさい！もっと攻める！',
        'ガアア！関係ない！',
      ],
      DialogueTrigger.opponentBadMove: ['ぶっ壊す！今だ！', 'ドカン！', 'ガアアア！遠慮はしない！'],
      DialogueTrigger.aiWins: ['ガアア！力こそ全てだ！勝った！', '壊した壊した全部壊した！'],
      DialogueTrigger.aiLoses: ['なんで……全力で攻めたのに……', 'ガアア……負けた……次は絶対壊す！'],
    },
  ),

  'sennin': AiPersonality(
    attackBias: 0.5,
    defenceBias: 2.0,
    greedBias: 0.8,
    depthBonus: 2,
    dialogues: {
      DialogueTrigger.gameStart: [
        '急ぐことはない。全ては見えておる。',
        '時間よりも深みを選ぶ。',
        '仙人の境地で参ろう。',
      ],
      DialogueTrigger.opponentGoodMove: [
        'ほほ……良い読みじゃ。先が楽しみになってきた。',
        'なかなか。それでも防ぎ切る。',
        'うむ、面白い手じゃ。',
      ],
      DialogueTrigger.opponentBadMove: [
        'そこは無理だと分かっておったよ。',
        'ほほほ……読んでいたとも。',
        '急ぎすぎたのう。',
      ],
      DialogueTrigger.aiWins: ['ほほほ……急がず焦らず。これが仙人の将棋じゃ。', '千年の修行の成果よ。'],
      DialogueTrigger.aiLoses: ['ほほ……まだ修行が足りんかったのう。', '見事じゃ……これほどの使い手に会えて嬉しい。'],
    },
  ),
};

/// キャラIDからパーソナリティを取得（存在しなければnull）
AiPersonality? getPersonality(String? characterId) {
  if (characterId == null) return null;
  return characterPersonalities[characterId];
}

final _dialogueRand = Random();

/// キャラIDからランダムなセリフを取得
String? getRandomDialogue(String? characterId, DialogueTrigger trigger) {
  final personality = getPersonality(characterId);
  if (personality == null) return null;
  final lines = personality.dialogues[trigger];
  if (lines == null || lines.isEmpty) return null;
  return lines[_dialogueRand.nextInt(lines.length)];
}
