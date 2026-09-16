/// Static catalogue of mental-health resources for the Resources screen
/// (Chapter 4 "Browse Resources"). Curated, self-help content; in a full build
/// this could come from a remote catalogue.
library;

enum ResourceFormat { article, video, audio }

/// The kinds of content a resource body is built from. Keeping the body as
/// structured blocks (rather than one blob of text) lets the detail screen
/// style prose, lists, and callouts differently without parsing markup.
enum BlockKind { paragraph, bullets, steps, callout }

class ResourceBlock {
  final BlockKind kind;

  /// Prose for [BlockKind.paragraph] and [BlockKind.callout]; null otherwise.
  final String? text;

  /// Entries for [BlockKind.bullets] (unordered) and [BlockKind.steps]
  /// (numbered); empty otherwise.
  final List<String> items;

  /// Heading on a callout, e.g. "Tip" or "Remember".
  final String? label;

  const ResourceBlock._({
    required this.kind,
    this.text,
    this.items = const [],
    this.label,
  });

  const ResourceBlock.paragraph(String text)
      : this._(kind: BlockKind.paragraph, text: text);

  const ResourceBlock.bullets(List<String> items)
      : this._(kind: BlockKind.bullets, items: items);

  const ResourceBlock.steps(List<String> items)
      : this._(kind: BlockKind.steps, items: items);

  /// A gentle aside — reassurance rather than instruction.
  const ResourceBlock.remember(String text)
      : this._(kind: BlockKind.callout, text: text, label: "Remember");

  /// A practical pointer on using the technique.
  const ResourceBlock.tip(String text)
      : this._(kind: BlockKind.callout, text: text, label: "Tip");
}

class MentalHealthResource {
  final String title;
  final String topic; // e.g. Anxiety, Stress, Depression, Sleep, Mindfulness
  final ResourceFormat format;

  /// One-line description shown on the card and at the top of the detail view.
  final String summary;

  /// Optional line under the title on the detail screen, e.g. "What is
  /// anxiety?".
  final String? subtitle;

  /// The full readable content, shown on the detail screen.
  final List<ResourceBlock> body;

  const MentalHealthResource({
    required this.title,
    required this.topic,
    required this.format,
    required this.summary,
    required this.body,
    this.subtitle,
  });
}

const List<String> resourceTopics = [
  'Anxiety',
  'Stress',
  'Depression',
  'Sleep',
  'Mindfulness',
];

const List<MentalHealthResource> kResources = [
  // ---- Anxiety -----------------------------------------------------------
  MentalHealthResource(
    title: 'Understanding Anxiety',
    topic: 'Anxiety',
    format: ResourceFormat.article,
    summary:
        'What anxiety is, how it shows up in your thoughts and body, and when '
        'it may be worth reaching out for support.',
    subtitle: 'What is anxiety?',
    body: [
      ResourceBlock.paragraph(
          "Anxiety is a natural response to situations that make us feel "
          "worried, uncertain, or threatened. It can affect our thoughts, "
          "emotions, and body. You may notice excessive worrying, difficulty "
          "concentrating, restlessness, or physical sensations such as a "
          "racing heart."),
      ResourceBlock.paragraph(
          "A certain amount of anxiety is normal and can help us prepare for "
          "challenges. However, when anxiety becomes frequent, overwhelming, "
          "or begins to interfere with everyday activities, it may be helpful "
          "to talk to someone you trust or seek professional support."),
      ResourceBlock.remember(
          "Feeling anxious does not mean that something is wrong with you. Be "
          "patient with yourself and take things one step at a time."),
    ],
  ),
  MentalHealthResource(
    title: 'Box Breathing (4-4-4-4)',
    topic: 'Anxiety',
    format: ResourceFormat.audio,
    summary:
        'A structured 4-4-4-4 breathing exercise to help you slow down when '
        'you feel tense or overwhelmed.',
    subtitle: 'A simple breathing exercise',
    body: [
      ResourceBlock.paragraph(
          "Box breathing is a structured breathing technique that can help you "
          "slow down and focus on your breathing when you feel tense or "
          "overwhelmed."),
      ResourceBlock.paragraph("Try this:"),
      ResourceBlock.steps([
        "Breathe in slowly for 4 seconds.",
        "Hold your breath gently for 4 seconds.",
        "Breathe out slowly for 4 seconds.",
        "Pause for 4 seconds.",
        "Repeat for a few rounds.",
      ]),
      ResourceBlock.paragraph(
          "Try to keep your breathing comfortable rather than forcing it. If "
          "holding your breath feels uncomfortable, simply breathe slowly and "
          "naturally."),
      ResourceBlock.tip(
          "Use this exercise when you need a short moment to pause and "
          "refocus."),
    ],
  ),

  // ---- Stress ------------------------------------------------------------
  MentalHealthResource(
    title: 'Managing Everyday Stress',
    topic: 'Stress',
    format: ResourceFormat.article,
    summary:
        'Where everyday stress comes from, and practical ways to protect your '
        'energy one step at a time.',
    body: [
      ResourceBlock.paragraph(
          "Stress can happen when the demands placed on us feel greater than "
          "the time, energy, or resources we have available. School, work, "
          "relationships, finances, and everyday responsibilities can all "
          "contribute to stress."),
      ResourceBlock.paragraph(
          "Some helpful ways to manage everyday stress include:"),
      ResourceBlock.bullets([
        "Break large tasks into smaller steps.",
        "Take short breaks when working for long periods.",
        "Get enough rest.",
        "Talk to someone you trust.",
        "Make time for activities you enjoy.",
        "Practice slow breathing or relaxation exercises.",
        "Focus on what you can control rather than everything at once.",
      ]),
      ResourceBlock.remember(
          "You don't have to solve everything at the same time. Start with one "
          "small, manageable step."),
    ],
  ),
  MentalHealthResource(
    title: 'Progressive Muscle Relaxation',
    topic: 'Stress',
    format: ResourceFormat.video,
    summary:
        'Release physical tension by gently tensing and relaxing muscle groups '
        'one at a time.',
    subtitle: 'Relax your body, one muscle group at a time',
    body: [
      ResourceBlock.paragraph(
          "Progressive Muscle Relaxation (PMR) is a relaxation technique that "
          "involves gently tensing and then relaxing different muscle groups."),
      ResourceBlock.paragraph(
          "Find a comfortable position and begin with one area of your body. "
          "Gently tense the muscles for a few seconds, then release and notice "
          "the difference between tension and relaxation. Move gradually "
          "through other muscle groups."),
      ResourceBlock.paragraph("For example:"),
      ResourceBlock.paragraph("Tense → pause → release → relax."),
      ResourceBlock.paragraph(
          "Keep the tension gentle and stop if anything causes pain or "
          "discomfort."),
      ResourceBlock.tip(
          "Practising PMR regularly may help you become more aware of physical "
          "tension and create moments of relaxation."),
    ],
  ),

  // ---- Depression --------------------------------------------------------
  MentalHealthResource(
    title: 'Recognising Low Mood',
    topic: 'Depression',
    format: ResourceFormat.article,
    summary:
        'How to notice changes in your mood, energy, and sleep — and when to '
        'reach out for help.',
    body: [
      ResourceBlock.paragraph(
          "Everyone experiences periods of sadness or low mood. You might feel "
          "tired, lose interest in activities, have difficulty concentrating, "
          "or feel less motivated than usual."),
      ResourceBlock.paragraph(
          "Low mood can sometimes improve with time and support. However, if "
          "these feelings persist, become overwhelming, or significantly "
          "affect your everyday life, consider talking to a trusted person or "
          "a qualified mental-health professional."),
      ResourceBlock.paragraph("Try to notice changes in:"),
      ResourceBlock.bullets([
        "Your mood",
        "Your energy",
        "Your sleep",
        "Your appetite",
        "Your interest in activities",
        "Your ability to manage everyday responsibilities",
      ]),
      ResourceBlock.remember(
          "You don't have to handle difficult feelings alone. Asking for "
          "support is a strength."),
    ],
  ),
  MentalHealthResource(
    title: 'Behavioural Activation Basics',
    topic: 'Depression',
    format: ResourceFormat.article,
    summary:
        'Small, gradual activities that can gently lift mood when motivation '
        'feels low.',
    subtitle: 'Small actions can make a difference',
    body: [
      ResourceBlock.paragraph(
          "When someone feels low, they may stop doing activities they "
          "previously enjoyed or find meaningful. Unfortunately, withdrawing "
          "completely can sometimes make low mood feel even heavier."),
      ResourceBlock.paragraph(
          "Behavioural activation focuses on gradually returning to meaningful "
          "or enjoyable activities, even when motivation is low."),
      ResourceBlock.paragraph("Start small:"),
      ResourceBlock.bullets([
        "Take a short walk.",
        "Call a friend.",
        "Tidy one small area.",
        "Listen to music.",
        "Work on one simple task.",
        "Spend a little time doing something you value.",
      ]),
      ResourceBlock.paragraph(
          "You don't have to wait until you feel motivated. A small action can "
          "sometimes come before the motivation."),
    ],
  ),

  // ---- Sleep -------------------------------------------------------------
  MentalHealthResource(
    title: 'Better Sleep Habits',
    topic: 'Sleep',
    format: ResourceFormat.article,
    summary:
        'Habits and a wind-down routine that create an environment supporting '
        'healthy rest.',
    body: [
      ResourceBlock.paragraph(
          "Good sleep habits can help create an environment that supports "
          "healthy rest."),
      ResourceBlock.paragraph("Consider:"),
      ResourceBlock.bullets([
        "Keeping a consistent sleep and wake time.",
        "Creating a relaxing bedtime routine.",
        "Making your sleeping environment comfortable and quiet.",
        "Reducing stimulating activities close to bedtime.",
        "Avoiding large meals or excessive caffeine close to bedtime.",
        "Using your bed mainly for sleep and rest.",
      ]),
      ResourceBlock.paragraph(
          "If sleep problems continue for a long time or seriously affect your "
          "daily life, consider discussing them with a healthcare "
          "professional."),
      ResourceBlock.tip(
          "Don't pressure yourself to achieve perfect sleep. Focus on creating "
          "consistent, calming habits."),
    ],
  ),
  MentalHealthResource(
    title: 'Body Scan for Sleep',
    topic: 'Sleep',
    format: ResourceFormat.audio,
    summary:
        'A calming body-scan practice to help your body and mind settle at '
        'bedtime.',
    subtitle: 'A gentle relaxation exercise',
    body: [
      ResourceBlock.paragraph(
          "A body scan involves slowly bringing your attention to different "
          "parts of your body."),
      ResourceBlock.paragraph(
          "Lie comfortably and begin by noticing your breathing. Then gently "
          "move your attention from one part of your body to another — for "
          "example, from your feet upward. Notice sensations such as warmth, "
          "heaviness, or tension without judging them."),
      ResourceBlock.paragraph(
          "If you notice tension, allow yourself to soften and relax where "
          "possible."),
      ResourceBlock.paragraph(
          "If your mind wanders, gently return your attention to your body and "
          "breathing."),
      ResourceBlock.remember(
          "The goal isn't to force yourself to sleep. It's simply to create a "
          "calm moment for your body and mind."),
    ],
  ),

  // ---- Mindfulness -------------------------------------------------------
  MentalHealthResource(
    title: 'Intro to Mindfulness',
    topic: 'Mindfulness',
    format: ResourceFormat.video,
    summary:
        'What mindfulness is, and a simple practice you can use during '
        'ordinary daily activities.',
    subtitle: 'What is mindfulness?',
    body: [
      ResourceBlock.paragraph(
          "Mindfulness means paying attention to the present moment with "
          "openness and without immediately judging what you notice."),
      ResourceBlock.paragraph(
          "For example, while drinking water, you could pay attention to its "
          "temperature, taste, and how it feels as you drink it, instead of "
          "being distracted by other thoughts."),
      ResourceBlock.paragraph("A simple mindfulness practice is:"),
      ResourceBlock.paragraph("Pause → Breathe → Notice → Accept → Continue."),
      ResourceBlock.paragraph(
          "Your mind will naturally wander. When it does, simply notice that "
          "it has wandered and gently bring your attention back to the "
          "present."),
      ResourceBlock.tip(
          "Mindfulness doesn't require a special place or a lot of time. You "
          "can practise it during ordinary daily activities."),
    ],
  ),
  MentalHealthResource(
    title: 'Mindful Journaling',
    topic: 'Mindfulness',
    format: ResourceFormat.article,
    summary:
        'Prompts to help you notice and name your feelings without judging '
        'yourself.',
    subtitle: 'Use writing to understand your thoughts and feelings',
    body: [
      ResourceBlock.paragraph(
          "Mindful journaling involves writing about your experiences while "
          "paying attention to your thoughts and feelings without judging "
          "yourself."),
      ResourceBlock.paragraph("You can begin with simple prompts:"),
      ResourceBlock.bullets([
        "How am I feeling right now?",
        "What is on my mind today?",
        "What has been difficult today?",
        "What went well today?",
        "What do I need right now?",
        "What is one thing I am grateful for?",
      ]),
      ResourceBlock.paragraph(
          "You don't need to write perfectly or produce a long entry. Even a "
          "few honest sentences can help you pause and reflect."),
      ResourceBlock.remember(
          "Your journal is a space for reflection, not a place where you need "
          "to have all the answers."),
    ],
  ),
];
