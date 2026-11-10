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

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get close => 'Close';

  @override
  String get continueLabel => 'Continue';

  @override
  String get loadFailedRetry => 'Couldn\'t load · Retry';

  @override
  String get unknownAnimal => 'Animal';

  @override
  String get anonymousFriend => 'Anonymous friend';

  @override
  String get rarityCommon => 'Common';

  @override
  String get rarityRare => 'Rare';

  @override
  String get rarityEpic => 'Epic';

  @override
  String get rarityUnknown => 'Unknown';

  @override
  String get avatarSemantic => 'Animal avatar';

  @override
  String avatarSemanticNamed(String name) {
    return 'Avatar: $name';
  }

  @override
  String get animalLocked => 'Locked animal';

  @override
  String get errTooFast => 'Too many actions. Please wait and try again.';

  @override
  String get errServiceRetry =>
      'The service is temporarily unavailable. Please try again.';

  @override
  String get errProfileRequired => 'Finish your profile before continuing.';

  @override
  String get errInvalidAlias => 'Nicknames need 3 to 20 valid characters.';

  @override
  String get errInvalidBirthdate => 'Invalid date of birth.';

  @override
  String get errAliasCooldown =>
      'You can change your nickname once every 24 hours.';

  @override
  String get errProRequired => 'This feature is for Pro members.';

  @override
  String get errAnimalNotOwned => 'You don\'t own this animal yet.';

  @override
  String get errSpinCooldown => 'It\'s not time for the next spin yet.';

  @override
  String get errCollectionComplete => 'You\'ve completed the collection.';

  @override
  String get errFileTooLarge => 'The photo exceeds the 10 MB limit.';

  @override
  String get errUnsupportedMediaType =>
      'This photo format isn\'t supported yet.';

  @override
  String get errUploadLimit =>
      'You\'ve reached the photo upload limit for this hour.';

  @override
  String get errPhotoLimit => 'You\'ve reached today\'s posting limit.';

  @override
  String get errSwipeLimit => 'You\'re out of right swipes for today.';

  @override
  String get errTooManySearches => 'You\'re searching too fast. Wait a moment.';

  @override
  String get errNoBoost => 'You have no Boosts left.';

  @override
  String get errInviteLimit => 'You\'ve reached today\'s invite limit.';

  @override
  String get errReportLimit => 'You\'ve reached today\'s report limit.';

  @override
  String get errChatRateLimit => 'You\'re sending messages too fast.';

  @override
  String get errMediaNotReady => 'The photo is still being processed.';

  @override
  String get errInvalidMessage => 'Invalid message.';

  @override
  String get errGlyphInvalidPoints => 'Invalid symbol stroke.';

  @override
  String get errGlyphInvalidColor => 'This symbol color isn\'t supported.';

  @override
  String get errGlyphDuplicate => 'This symbol is already in the conversation.';

  @override
  String get errGlyphLimit => 'The conversation has reached its symbol limit.';

  @override
  String get errGlyphNotFound => 'Symbol not found.';

  @override
  String get errGlyphNotActive => 'This symbol is no longer in use.';

  @override
  String get errGlyphNotOwner => 'You can\'t delete someone else\'s symbol.';

  @override
  String get errGlyphSequenceTooLong => 'The sentence has too many symbols.';

  @override
  String get errInvalidGlyphMessage => 'Invalid symbol message.';

  @override
  String get errGlyphCreateRateLimit => 'You\'re creating symbols too fast.';

  @override
  String get errReceiptAlreadyUsed => 'This transaction has already been used.';

  @override
  String get errStoreUnavailable =>
      'The store is temporarily unavailable. Please try again.';

  @override
  String get errInvalidReceipt => 'Couldn\'t verify the transaction.';

  @override
  String get errServiceUnavailable => 'The service is temporarily unavailable.';

  @override
  String get errIdentityUnavailable =>
      'Couldn\'t verify your account right now.';

  @override
  String get signInHeadline => 'Closer together,\nstill yourself.';

  @override
  String get signInSubtitle =>
      'Share moments with friends. Everyone is a one-of-a-kind animal — no real names.';

  @override
  String get signInOpening => 'Opening sign-in…';

  @override
  String get signInEmail => 'Sign in with email';

  @override
  String signInFailed(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String get openDemoAccount => 'Open demo account';

  @override
  String get signInPrivacy =>
      'We never show your real name, email or exact location.';

  @override
  String get termsAgree => 'I agree to the Terms of Use and Privacy Policy.';

  @override
  String get pickBirthdate => 'Pick your date of birth';

  @override
  String get safetySetupTitle => 'Safety setup';

  @override
  String get birthdateSection => 'Date of birth';

  @override
  String get birthAgeSpace => 'Each age group gets a fitting space.';

  @override
  String get birthPrivacy =>
      'Your date of birth is only used to determine your age group. It never appears on your profile.';

  @override
  String get dayLabel => 'Day';

  @override
  String get monthLabel => 'Month';

  @override
  String get yearLabel => 'Year';

  @override
  String get tapToPickBirthdate => 'Tap to pick your date of birth';

  @override
  String get aliasSuggestion1 => 'Mischief Cloud';

  @override
  String get aliasSuggestion2 => 'Dreamy Fox';

  @override
  String get aliasSuggestion3 => 'Sparkling Sun';

  @override
  String get aliasSuggestion4 => 'Fluffy Bear';

  @override
  String get revealSection => 'Your very own avatar';

  @override
  String get photoDeveloping => 'developing…';

  @override
  String get revealReady => 'Ready to meet your animal?';

  @override
  String revealGreeting(String alias) {
    return 'Hi $alias';
  }

  @override
  String get aliasNotRealName =>
      'Your nickname doesn\'t have to be your real name.';

  @override
  String get spinning => 'Spinning…';

  @override
  String animalUniqueAvatar(String animal) {
    return '$animal · nobody else has this avatar';
  }

  @override
  String get nicknameLabel => 'Nickname';

  @override
  String get randomNickname => 'Generate a random nickname';

  @override
  String get registering => 'Registering…';

  @override
  String get spinAvatar => 'Spin avatar';

  @override
  String get enterApp => 'Enter the app';

  @override
  String get billingProPlan => 'Pro plan';

  @override
  String billingProPlanDays(int days) {
    return 'Pro plan · $days days';
  }

  @override
  String billingBoost(int quantity) {
    return 'Discovery Boost × $quantity';
  }

  @override
  String billingPriorityInvite(int quantity) {
    return 'Priority invite × $quantity';
  }

  @override
  String billingAnimalPack(String item) {
    return 'Animal pack $item';
  }

  @override
  String get billingDemoDisabled => 'Purchases are disabled in demo mode.';

  @override
  String get billingTransactionError => 'The transaction failed.';

  @override
  String get billingCheckoutOpened =>
      'Payment page opened. Come back to the app after paying to refresh.';

  @override
  String get billingBrowserFailed => 'Couldn\'t open the browser.';

  @override
  String get billingWebPaymentOff =>
      'Web payment isn\'t enabled on the server.';

  @override
  String get billingNotOnWeb => 'This product isn\'t sold on the web yet.';

  @override
  String get billingSessionFailed => 'Couldn\'t create a payment session.';

  @override
  String get billingUpdated => 'Your purchases have been updated.';

  @override
  String get billingVerified => 'Transaction verified.';

  @override
  String get billingNotVerified =>
      'The server couldn\'t verify the transaction. It wasn\'t completed.';

  @override
  String get billingCanceled => 'Transaction canceled.';

  @override
  String get proLoadFailed => 'Couldn\'t load the store · Retry';

  @override
  String get proHeadline => 'More ways to connect';

  @override
  String get proPerkBoost => 'Discovery Boost';

  @override
  String get proPerkInvite => 'Priority friend invites';

  @override
  String get proMinorNotice => 'Offers aren\'t shown for accounts under 18.';

  @override
  String get proNoWebProducts => 'No products are sold on the web yet.';

  @override
  String get proWebPaymentNote =>
      'Pay on the Animal Locket website (VietQR/PayPal). When you\'re done, tap \"Back to app\".';

  @override
  String proViaStore(String product, String price) {
    return 'Via store: $product · $price';
  }

  @override
  String get proRestore => 'Restore store purchases';

  @override
  String get proCurrentPro => 'You\'re on Pro';

  @override
  String proCurrentProUntil(String date) {
    return 'You\'re on Pro until $date';
  }

  @override
  String get proCurrentFree => 'You\'re on the Free plan';

  @override
  String proWallet(int boosts, int invites) {
    return 'Boosts: $boosts · Priority invites: $invites';
  }

  @override
  String get newMoment => 'New moment';

  @override
  String get flashMode => 'Change flash mode';

  @override
  String get pickFromGallery => 'Choose from gallery';

  @override
  String get flipCamera => 'Flip camera';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get cameraPermission => 'Allow camera access to capture moments.';

  @override
  String get allowCamera => 'Allow camera';

  @override
  String get previewSendingFirst =>
      'Still sending the previous photo — one moment.';

  @override
  String get previewTitle => 'Preview';

  @override
  String get messageLabel => 'Message';

  @override
  String get messageHintFriends => 'Write something for your friends…';

  @override
  String get sendingPhoto => 'Sending the previous photo…';

  @override
  String get sendToFriends => 'Send to friends';

  @override
  String get retake => 'Retake';

  @override
  String get previewNote =>
      'The photo goes to all your friends. Choosing recipients isn\'t supported yet.';

  @override
  String get sendSending => 'Sending…';

  @override
  String get sendSent => 'Sent';

  @override
  String get sendRejected => 'Photo not accepted';

  @override
  String get sendFailed => 'Send failed — check your connection';

  @override
  String get chatListTitle => 'Chats';

  @override
  String get chatOnlyFriends => 'Messaging is only open between friends.';

  @override
  String get chatEmpty => 'No conversations yet.';

  @override
  String get chatStart => 'Start chatting';

  @override
  String get chatRecent => 'Recent messages';

  @override
  String unreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '1 unread message',
    );
    return '$_temp0';
  }

  @override
  String get friendsLabel => 'Friends';

  @override
  String swipesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count right swipes left today',
      one: '1 right swipe left today',
    );
    return '$_temp0';
  }

  @override
  String get enableLocationHint =>
      'Turn on location to find people nearby. For now you only see people who are online.';

  @override
  String get enableLocation => 'Turn on location';

  @override
  String get discoverSlow =>
      'The service is slow, so the deck may be incomplete.';

  @override
  String get skip => 'Skip';

  @override
  String get useBoost => 'Use Boost';

  @override
  String get addFriend => 'Add friend';

  @override
  String get friendsMade => 'You\'re now friends! You can start chatting.';

  @override
  String get boostUsed => 'Used 1 Boost.';

  @override
  String get online => 'Online';

  @override
  String get anonymousAnimal => 'Anonymous animal';

  @override
  String get deckEmpty => 'No new cards';

  @override
  String get reload => 'Reload';

  @override
  String get findNewFriends => 'Find new friends';

  @override
  String get locationConsent =>
      'Location is only requested when you turn on discovery. If you decline, you can still use online mode.';

  @override
  String get enableDiscovery => 'Turn on discovery';

  @override
  String discoverLoadFailedCode(String code) {
    return 'Couldn\'t load Discover ($code).';
  }

  @override
  String get discoverLoadFailed => 'Couldn\'t load Discover.';

  @override
  String get distUnder1km => 'under 1 km';

  @override
  String get dist1to3km => '1–3 km';

  @override
  String get distUnder3km => 'under 3 km';

  @override
  String get dist3to10km => '3–10 km';

  @override
  String get distOver10km => 'over 10 km';

  @override
  String get feedTitle => 'Moments';

  @override
  String get feedLoadFailed =>
      'Couldn\'t load the feed. Check your connection.';

  @override
  String get feedEmpty =>
      'No moments yet\nTake a photo or add friends to get started.';

  @override
  String get feedDegraded =>
      'Part of the service is slow. The feed may be incomplete.';

  @override
  String get unlike => 'Unlike';

  @override
  String get like => 'Like';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get dayToday => 'Today';

  @override
  String get dayYesterday => 'Yesterday';

  @override
  String get noPhotosYet => 'No photos yet.';

  @override
  String get befriendToSee => 'Become friends to see this person\'s photos.';

  @override
  String get photosLoadFailed => 'Couldn\'t load photos · Retry';

  @override
  String get morePhotos => 'Show more photos';

  @override
  String get postProcessing => 'Processing';

  @override
  String get postRejected => 'Rejected';

  @override
  String get postRejectedPhoto => 'Photo rejected';

  @override
  String get postProcessingPhoto => 'Photo is being processed';

  @override
  String get deletePhoto => 'Delete photo';

  @override
  String get deletePhotoQ => 'Delete this photo?';

  @override
  String get deletePhotoBody => 'Your friends won\'t see this photo anymore.';

  @override
  String get deletePhotoFailed =>
      'Couldn\'t delete the photo. Try again later.';

  @override
  String get friendsAndRequests => 'Friends & requests';

  @override
  String tabFriends(int count) {
    return 'Friends $count';
  }

  @override
  String tabRequests(int count) {
    return 'Requests $count';
  }

  @override
  String tabSent(int count) {
    return 'Sent $count';
  }

  @override
  String get noFriends => 'No friends yet.';

  @override
  String get offline => 'Offline';

  @override
  String get viewProfile => 'View profile';

  @override
  String get noIncoming => 'No new requests.';

  @override
  String get noOutgoing => 'You haven\'t sent any requests.';

  @override
  String get distanceHidden => 'Distance is hidden to protect privacy';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get settings => 'Settings';

  @override
  String get changeNickname => 'Change nickname';

  @override
  String get memberPro => 'Pro member';

  @override
  String get memberFree => 'Free member';

  @override
  String get ownedAvatars => 'Avatars owned';

  @override
  String get myPhotos => 'My photos';

  @override
  String get noMyPhotos => 'You haven\'t posted any photos.';

  @override
  String get collection => 'Collection';

  @override
  String get collectionNote =>
      'Each avatar belongs only to you — nobody else can have it.';

  @override
  String get upgradePro => 'Upgrade Pro';

  @override
  String friendsCount(int count) {
    return 'Friends ($count)';
  }

  @override
  String get seeAll => 'See all';

  @override
  String get friendsLoadFailed => 'Couldn\'t load friends · Retry';

  @override
  String get noFriendsYet => 'No friends yet.';

  @override
  String get findFriends => 'Find friends';

  @override
  String openProfileOf(String name) {
    return 'Open $name\'s profile';
  }

  @override
  String get profileLoadFailed => 'Couldn\'t load the profile.';

  @override
  String photosOf(String name) {
    return '$name\'s photos';
  }

  @override
  String noPhotosOf(String name) {
    return '$name hasn\'t posted any photos.';
  }

  @override
  String get anonymousProfile => 'Anonymous profile';

  @override
  String get message => 'Message';

  @override
  String get unfriend => 'Unfriend';

  @override
  String get report => 'Report';

  @override
  String get block => 'Block';

  @override
  String get blockQ => 'Block this person?';

  @override
  String get blockBody => 'You won\'t be able to find or message each other.';

  @override
  String get reportDetails => 'Details';

  @override
  String get sendReport => 'Send report';

  @override
  String get reportSent => 'Report sent.';

  @override
  String get settingsTitle => 'Settings & privacy';

  @override
  String get allowDiscovery => 'Allow discovery';

  @override
  String get discoveryOffNote =>
      'Turn off to delete your location and stop appearing in the deck.';

  @override
  String get blockedSection => 'Blocked';

  @override
  String get nobodyBlocked => 'You haven\'t blocked anyone.';

  @override
  String get unblock => 'Unblock';

  @override
  String get signOut => 'Sign out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountQ => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'Your photos, messages and profile will be deleted. This can\'t be undone.';

  @override
  String get keepAccount => 'Keep account';

  @override
  String get finalConfirm => 'Final confirmation';

  @override
  String get typeDeleteWord => 'Type DELETE to confirm';

  @override
  String get deleteWord => 'DELETE';

  @override
  String get deleteForever => 'Delete permanently';

  @override
  String get themeSection => 'Appearance colors';

  @override
  String get themeShu => 'Shu · Vermilion';

  @override
  String get themeYuzu => 'Yuzu · Citron yellow';

  @override
  String get themeSakura => 'Sakura · Cherry blossom';

  @override
  String get themeSora => 'Sora · Sky blue';

  @override
  String get glyphSysAgree => 'Agree';

  @override
  String get glyphSysHurry => 'Hurry up';

  @override
  String get glyphSysBusy => 'Busy';

  @override
  String get glyphSysCoffee => 'Coffee?';

  @override
  String get glyphSysHungry => 'Hungry';

  @override
  String get glyphSysComing => 'On my way';

  @override
  String get view => 'View';

  @override
  String unfriendQ(String name) {
    return 'Unfriend $name?';
  }
}
