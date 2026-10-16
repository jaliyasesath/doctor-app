import 'package:flutter/material.dart';
import 'dart:typed_data';

/// Module labels only; never translates medical post content automatically.
class HealthPostLabels {
  const HealthPostLabels(this.language);
  final String language;
  String t(String key) =>
      (_labels[language]?[key] ?? _labels['en']?[key] ?? key);
  static const _labels = <String, Map<String, String>>{
    'en': {
      'feed': 'Health Feed',
      'topics': 'Explore Topics',
      'all': 'All',
      'latest': 'Latest',
      'following': 'Following',
      'helpful': 'Helpful',
      'save': 'Save',
      'saved': 'Saved',
      'share': 'Share',
      'follow': 'Follow',
      'unfollow': 'Unfollow',
      'report': 'Report post',
      'retry': 'Retry',
      'more': 'Load more',
      'empty': 'No posts here yet.',
      'noFollowing': 'Follow doctors to see their updates here.',
      'explore': 'Explore posts',
      'myPosts': 'My Health Posts',
      'create': 'Create Post',
      'published': 'Published',
      'drafts': 'Drafts',
      'preview': 'Preview',
      'draft': 'Save Draft',
      'publish': 'Publish',
      'edit': 'Edit',
      'delete': 'Delete',
      'content': 'Share something helpful…',
      'title': 'Title (optional)',
      'source': 'Source link (optional)',
      'language': 'Post language',
      'topic': 'Topic',
      'photo': 'Add photo',
      'removePhoto': 'Remove photo',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'deleteQuestion': 'Delete this post?',
      'search': 'Search your posts',
      'hidden': 'Hidden by administrator',
      'allLanguages': 'All languages',
      'contentRequired': 'Post content is required.',
      'updated': 'Post saved',
      'reportThanks': 'Report submitted. Thank you.',
      'reason': 'Reason for reporting',
      'viewAll': 'View all',
      'privateDraft': 'Drafts are visible only to you.',
      'readMore': 'Read more',
      'less': 'Show less',
      'sourceOpen': 'View source',
      'restart': 'Back to newest posts',
      'discard': 'Discard unsaved changes?',
      'community': 'Share helpful updates with your community',
      'verifiedOnly': 'Publishing is available to verified doctors.',
      'medicalPrivacy':
          'Share general health information. Do not include patient details or identifiable patient photos.',
    },
    'si': {
      'feed': 'සෞඛ්‍ය ලිපි',
      'topics': 'මාතෘකා',
      'all': 'සියල්ල',
      'latest': 'අලුත්ම',
      'following': 'අනුගමනය කරන',
      'helpful': 'ප්‍රයෝජනවත්',
      'save': 'සුරකින්න',
      'saved': 'සුරැකි ලිපි',
      'share': 'බෙදාගන්න',
      'follow': 'අනුගමනය',
      'unfollow': 'අනුගමනය නවත්වන්න',
      'report': 'වාර්තා කරන්න',
      'retry': 'නැවත උත්සාහ කරන්න',
      'more': 'තවත් බලන්න',
      'empty': 'තවම ලිපි නැහැ.',
      'noFollowing': 'වෛද්‍යවරුන්ගේ ලිපි බැලීමට ඔවුන් අනුගමනය කරන්න.',
      'explore': 'ලිපි බලන්න',
      'myPosts': 'මගේ සෞඛ්‍ය ලිපි',
      'create': 'ලිපියක් ලියන්න',
      'published': 'පළ කළ',
      'drafts': 'කෙටුම්පත්',
      'preview': 'පෙරදසුන',
      'draft': 'කෙටුම්පත සුරකින්න',
      'publish': 'පළ කරන්න',
      'edit': 'සංස්කරණය',
      'delete': 'මකන්න',
      'content': 'ප්‍රයෝජනවත් අදහසක් බෙදාගන්න…',
      'title': 'මාතෘකාව (අවශ්‍ය නම්)',
      'source': 'මූලාශ්‍ර සබැඳිය (අවශ්‍ය නම්)',
      'language': 'ලිපියේ භාෂාව',
      'topic': 'මාතෘකාව',
      'photo': 'ඡායාරූපයක් එක් කරන්න',
      'removePhoto': 'ඡායාරූපය ඉවත් කරන්න',
      'cancel': 'අවලංගු කරන්න',
      'confirm': 'තහවුරු කරන්න',
      'deleteQuestion': 'මෙම ලිපිය මකන්නද?',
      'search': 'ඔබේ ලිපි සොයන්න',
      'hidden': 'පරිපාලක විසින් සඟවා ඇත',
      'allLanguages': 'සියලු භාෂා',
      'contentRequired': 'ලිපියේ විස්තර අවශ්‍යයි.',
      'updated': 'ලිපිය සුරැකුණා',
      'reportThanks': 'වාර්තාව ලැබුණා. ස්තුතියි.',
      'reason': 'වාර්තා කිරීමට හේතුව',
      'viewAll': 'සියල්ල බලන්න',
      'privateDraft': 'කෙටුම්පත් පෙනෙන්නේ ඔබට පමණි.',
      'readMore': 'තවත් කියවන්න',
      'less': 'අඩුවෙන් පෙන්වන්න',
      'sourceOpen': 'මූලාශ්‍රය බලන්න',
      'restart': 'අලුත්ම ලිපි වෙත',
      'discard': 'සුරැකී නැති වෙනස්කම් ඉවත් කරන්නද?',
      'community': 'ප්‍රයෝජනවත් සෞඛ්‍ය තොරතුරු බෙදාගන්න',
      'verifiedOnly': 'තහවුරු කළ වෛද්‍යවරුන්ට පළ කළ හැකිය.',
      'medicalPrivacy':
          'පොදු සෞඛ්‍ය තොරතුරු පමණක් බෙදාගන්න. රෝගී විස්තර හෝ හඳුනාගත හැකි රෝගී ඡායාරූප ඇතුළත් නොකරන්න.',
    },
    'ta': {
      'feed': 'சுகாதாரப் பதிவுகள்',
      'topics': 'தலைப்புகள்',
      'all': 'அனைத்தும்',
      'latest': 'புதியவை',
      'following': 'பின்தொடர்பவை',
      'helpful': 'பயனுள்ளது',
      'save': 'சேமி',
      'saved': 'சேமித்தவை',
      'share': 'பகிர்',
      'follow': 'பின்தொடர்',
      'unfollow': 'பின்தொடர்வதை நிறுத்து',
      'report': 'புகாரளி',
      'retry': 'மீண்டும் முயல்க',
      'more': 'மேலும் காட்டு',
      'empty': 'இன்னும் பதிவுகள் இல்லை.',
      'noFollowing':
          'மருத்துவர்களின் பதிவுகளைப் பார்க்க அவர்களைப் பின்தொடரவும்.',
      'explore': 'பதிவுகளைப் பார்',
      'myPosts': 'எனது சுகாதாரப் பதிவுகள்',
      'create': 'பதிவை உருவாக்கு',
      'published': 'வெளியிட்டவை',
      'drafts': 'வரைவுகள்',
      'preview': 'முன்னோட்டம்',
      'draft': 'வரைவைச் சேமி',
      'publish': 'வெளியிடு',
      'edit': 'திருத்து',
      'delete': 'நீக்கு',
      'content': 'பயனுள்ள தகவலைப் பகிரவும்…',
      'title': 'தலைப்பு (விருப்பம்)',
      'source': 'மூல இணைப்பு (விருப்பம்)',
      'language': 'பதிவின் மொழி',
      'topic': 'தலைப்பு',
      'photo': 'புகைப்படம் சேர்',
      'removePhoto': 'புகைப்படத்தை நீக்கு',
      'cancel': 'ரத்துசெய்',
      'confirm': 'உறுதிசெய்',
      'deleteQuestion': 'இந்தப் பதிவை நீக்கவா?',
      'search': 'உங்கள் பதிவுகளைத் தேடு',
      'hidden': 'நிர்வாகியால் மறைக்கப்பட்டது',
      'allLanguages': 'அனைத்து மொழிகளும்',
      'contentRequired': 'பதிவின் விவரம் தேவை.',
      'updated': 'பதிவு சேமிக்கப்பட்டது',
      'reportThanks': 'புகார் சமர்ப்பிக்கப்பட்டது. நன்றி.',
      'reason': 'புகாருக்கான காரணம்',
      'viewAll': 'அனைத்தையும் பார்',
      'privateDraft': 'வரைவுகள் உங்களுக்கு மட்டுமே தெரியும்.',
      'readMore': 'மேலும் படி',
      'less': 'சுருக்கிக் காட்டு',
      'sourceOpen': 'மூலத்தைப் பார்',
      'restart': 'புதிய பதிவுகளுக்குச் செல்',
      'discard': 'சேமிக்காத மாற்றங்களை நீக்கவா?',
      'community': 'பயனுள்ள சுகாதாரத் தகவல்களைப் பகிரவும்',
      'verifiedOnly': 'சரிபார்க்கப்பட்ட மருத்துவர்கள் வெளியிடலாம்.',
      'medicalPrivacy':
          'பொது சுகாதாரத் தகவல்களை மட்டும் பகிரவும். நோயாளி விவரங்கள் அல்லது அடையாளம் காணக்கூடிய புகைப்படங்களைச் சேர்க்க வேண்டாம்.',
    },
  };
}

const healthLanguages = {'en': 'English', 'si': 'සිංහල', 'ta': 'தமிழ்'};

/// Load bytes through authenticated APIs. No bearer tokens appear in URLs or disk caches.
class HealthPostPhoto extends StatefulWidget {
  const HealthPostPhoto({
    super.key,
    required this.load,
    required this.identity,
  });
  final Future<Uint8List> Function() load;
  final String identity;
  @override
  State<HealthPostPhoto> createState() => _HealthPostPhotoState();
}

class _HealthPostPhotoState extends State<HealthPostPhoto> {
  late Future<Uint8List> _data;
  @override
  void initState() {
    super.initState();
    _data = widget.load();
  }

  @override
  void didUpdateWidget(covariant HealthPostPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) _data = widget.load();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1.85,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FutureBuilder<Uint8List>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: IconButton(
                    tooltip: 'Retry photo',
                    onPressed: () => setState(() {
                      _data = widget.load();
                    }),
                    icon: const Icon(Icons.refresh),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                cacheWidth: 900,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image_outlined)),
              );
            },
          ),
        ),
      );
}
