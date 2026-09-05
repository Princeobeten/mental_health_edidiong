/// Static catalogue of mental-health resources for the Resources screen
/// (Chapter 4 "Browse Resources"). Curated, self-help content; in a full build
/// this could come from a remote catalogue.
enum ResourceFormat { article, video, audio }

class MentalHealthResource {
  final String title;
  final String topic; // e.g. Anxiety, Stress, Depression, Sleep, Mindfulness
  final ResourceFormat format;
  final String summary;

  const MentalHealthResource({
    required this.title,
    required this.topic,
    required this.format,
    required this.summary,
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
  MentalHealthResource(
    title: 'Understanding Anxiety',
    topic: 'Anxiety',
    format: ResourceFormat.article,
    summary:
        'What anxiety is, common triggers, and grounding techniques you can use '
        'in the moment, like the 5-4-3-2-1 senses exercise.',
  ),
  MentalHealthResource(
    title: 'Box Breathing (4-4-4-4)',
    topic: 'Anxiety',
    format: ResourceFormat.audio,
    summary:
        'A short guided breathing exercise to calm the nervous system when you '
        'feel overwhelmed.',
  ),
  MentalHealthResource(
    title: 'Managing Everyday Stress',
    topic: 'Stress',
    format: ResourceFormat.article,
    summary:
        'Practical ways to break big problems into smaller steps and protect '
        'your energy during busy periods.',
  ),
  MentalHealthResource(
    title: 'Progressive Muscle Relaxation',
    topic: 'Stress',
    format: ResourceFormat.video,
    summary:
        'Release physical tension by tensing and relaxing muscle groups one at '
        'a time.',
  ),
  MentalHealthResource(
    title: 'Recognising Low Mood',
    topic: 'Depression',
    format: ResourceFormat.article,
    summary:
        'How to tell the difference between a tough day and persistent low '
        'mood, and when to reach out for help.',
  ),
  MentalHealthResource(
    title: 'Behavioural Activation Basics',
    topic: 'Depression',
    format: ResourceFormat.article,
    summary:
        'Small, planned activities that can gently lift mood when motivation '
        'feels low.',
  ),
  MentalHealthResource(
    title: 'Better Sleep Habits',
    topic: 'Sleep',
    format: ResourceFormat.article,
    summary:
        'A simple wind-down routine and a few habits that help you fall asleep '
        'more easily.',
  ),
  MentalHealthResource(
    title: 'Body Scan for Sleep',
    topic: 'Sleep',
    format: ResourceFormat.audio,
    summary:
        'A calming body-scan meditation to help you relax at bedtime.',
  ),
  MentalHealthResource(
    title: 'Intro to Mindfulness',
    topic: 'Mindfulness',
    format: ResourceFormat.video,
    summary:
        'What mindfulness is, why it helps, and a two-minute practice to try '
        'right now.',
  ),
  MentalHealthResource(
    title: 'Mindful Journaling',
    topic: 'Mindfulness',
    format: ResourceFormat.article,
    summary:
        'Prompts to help you notice and name your feelings without judgement.',
  ),
];
