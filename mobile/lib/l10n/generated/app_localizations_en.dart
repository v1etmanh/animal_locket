// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Animal Locket';

  @override
  String get photosTab => 'Photos';

  @override
  String get feedTab => 'Feed';

  @override
  String get discoverTab => 'Discover';

  @override
  String get chatTab => 'Chat';

  @override
  String get profileTab => 'Profile';

  @override
  String get retry => 'Retry';

  @override
  String get genericError => 'Something went wrong. Please try again.';

  @override
  String get conversationTitle => 'Conversation';

  @override
  String get messagesLoadError => 'Couldn\'t load messages.';

  @override
  String get messageSendFailed =>
      'Message not sent. Your text is still on screen.';

  @override
  String get messageHint => 'Message…';

  @override
  String get sendMessage => 'Send message';

  @override
  String get sendPhoto => 'Send photo';

  @override
  String get glyphModeOpen => 'Open symbol messaging';

  @override
  String get glyphModeClose => 'Close symbol messaging';

  @override
  String get glyphDrawLabel => 'Single-stroke symbol drawing area';

  @override
  String get glyphDrawHint => 'Draw one stroke here';

  @override
  String get glyphClearStroke => 'Clear stroke';

  @override
  String get glyphRecognizing => 'Recognizing…';

  @override
  String get glyphNoMatch =>
      'Symbol not recognized. Redraw it or create a new symbol.';

  @override
  String get glyphAmbiguous =>
      'This stroke looks like several symbols. Pick the right one.';

  @override
  String glyphMatched(String meaning) {
    return 'Recognized $meaning';
  }

  @override
  String get glyphAddToComposer => 'Add to sentence';

  @override
  String get glyphQuickPick => 'Quick pick';

  @override
  String get glyphComposerEmpty => 'No symbols in the sentence yet';

  @override
  String glyphRemoveToken(String meaning) {
    return 'Remove symbol $meaning';
  }

  @override
  String get glyphClearComposer => 'Clear the whole symbol sentence';

  @override
  String get glyphSend => 'Send symbols';

  @override
  String get glyphDictionary => 'Symbol dictionary';

  @override
  String get glyphCreate => 'Create symbol';

  @override
  String get glyphSystemTab => 'System';

  @override
  String get glyphPersonalTab => 'Personal';

  @override
  String get glyphConversationTab => 'Conversation';

  @override
  String get glyphDictionaryEmpty => 'No symbols in this tab yet.';

  @override
  String get glyphDictionaryError => 'Couldn\'t load the symbol dictionary.';

  @override
  String get glyphMeaningLabel => 'Symbol meaning';

  @override
  String get glyphMeaningHint => 'For example: Coffee?';

  @override
  String get glyphColorLabel => 'Symbol color';

  @override
  String get glyphSave => 'Save symbol';

  @override
  String get glyphDelete => 'Delete symbol';

  @override
  String get glyphCollisionWarning =>
      'This stroke is too similar to an existing symbol.';

  @override
  String get glyphTooShort => 'Draw a clearer stroke.';

  @override
  String get glyphFeatureWaitingBackend =>
      'Sending symbols is waiting for a compatible backend.';

  @override
  String get glyphShowMeaning => 'Show symbol meaning';

  @override
  String get glyphHideMeaning => 'Hide symbol meaning';

  @override
  String get glyphUnknownFallback =>
      'Couldn\'t load the symbol image. Showing a text fallback.';

  @override
  String get retryMessage => 'Resend message';

  @override
  String get conversationClosed => 'Conversation closed';

  @override
  String get languageSection => 'Language';
}
