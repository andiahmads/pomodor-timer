#import <AVFoundation/AVFoundation.h>
#include <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>
#include <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <EventKit/EventKit.h>

typedef NS_ENUM(NSInteger, SoundType) { SoundTypeBreak, SoundTypeWork };
typedef NS_ENUM(NSInteger, FocusMode) { FocusModeClassic, FocusModeDeepWork, FocusModeTimebox, FocusModeSpicy, FocusModeMarathon };
typedef NS_ENUM(NSInteger, Achievement) {
  AchievementFirstPomodoro, AchievementDailyStreak3, AchievementDailyStreak7, AchievementDailyStreak30,
  Achievement10Pomodoros, Achievement50Pomodoros, Achievement100Pomodoros, AchievementEarlyBird,
  AchievementNightOwl, AchievementMarathon, AchievementWeekWarrior, AchievementCentury
};

@interface PomodoroTask : NSObject
@property(strong) NSString *taskId;
@property(strong) NSString *title;
@property(assign) BOOL isCompleted;
@property(assign) NSInteger pomodorosSpent;
@end
@implementation PomodoroTask @end

@interface PomodoroRecord : NSObject
@property(strong) NSDate *date;
@property(assign) NSInteger workSeconds;
@property(assign) NSInteger completedPomodoros;
@property(strong) NSArray *focusHours;
@end
@implementation PomodoroRecord @end

@interface AchievementData : NSObject
@property(assign) Achievement type;
@property(strong) NSString *title;
@property(strong) NSString *achievedDescription;
@property(assign) BOOL unlocked;
@property(strong) NSDate *unlockedDate;
@property(assign) NSInteger xpReward;
- (instancetype)initWithType:(Achievement)type title:(NSString *)title desc:(NSString *)desc xp:(NSInteger)xp;
@end

@implementation AchievementData
- (instancetype)initWithType:(Achievement)type title:(NSString *)title desc:(NSString *)desc xp:(NSInteger)xp {
  self = [super init];
  if (self) {
    _type = type;
    _title = title;
    _achievedDescription = desc;
    _xpReward = xp;
    _unlocked = NO;
  }
  return self;
}
@end

@interface SoundLayer : NSObject
@property(strong) NSString *name;
@property(strong) NSString *filename;
@property(assign) float volume;
@property(strong) AVAudioPlayer *player;
@property(assign) BOOL isPlaying;
@end
@implementation SoundLayer @end

@interface FocusModeConfig : NSObject
@property(strong) NSString *name;
@property(assign) NSInteger workDuration;
@property(assign) NSInteger breakDuration;
@property(assign) NSInteger longBreakDuration;
@property(assign) NSInteger sessionsBeforeLongBreak;
@property(assign) BOOL autoStartNext;
@property(assign) BOOL enableDND;
@end
@implementation FocusModeConfig @end

@interface MiniPlayerWindow : NSWindow
@end
@implementation MiniPlayerWindow @end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property(strong) NSWindow *window;
@property(strong) NSWindow *miniPlayerWindow;
@property(strong) NSTextField *timeLabel;
@property(strong) NSProgressIndicator *progressBar;
@property(strong) NSButton *startButton;
@property(strong) NSButton *pauseButton;
@property(strong) NSButton *resetButton;
@property(strong) NSTimer *timer;
@property(assign) BOOL isWorkSession;
@property(assign) BOOL isRunning;
@property(assign) NSInteger totalSeconds;
@property(assign) NSInteger remainingSeconds;
@property(assign) NSInteger sessionCount;
@property(strong) AVAudioPlayer *soundType;
@property(assign) NSInteger workDuration;
@property(assign) NSInteger breakDuration;
@property(assign) NSInteger longBreakDuration;
@property(assign) FocusMode currentFocusMode;
@property(strong) NSStatusItem *statusItem;
@property(strong) NSWindow *settingsWindow;
@property(strong) NSPopUpButton *sessionSelector;
@property(strong) NSWindow *taskWindow;
@property(strong) NSTableView *taskTableView;
@property(strong) NSTextField *taskCountLabel;
@property(strong) NSMutableArray<PomodoroTask *> *tasks;
@property(strong) NSWindow *statsWindow;
@property(strong) NSWindow *musicWindow;
@property(strong) NSWindow *soundsWindow;
@property(strong) NSWindow *analyticsWindow;
@property(strong) NSMutableArray<PomodoroRecord *> *records;
@property(assign) NSInteger todayCompletedPomodoros;
@property(assign) NSInteger todayWorkSeconds;
@property(assign) NSInteger totalPomodorosAllTime;
@property(assign) NSInteger currentStreak;
@property(assign) NSInteger longestStreak;
@property(assign) NSInteger xpPoints;
@property(assign) NSInteger userLevel;
@property(strong) NSMutableArray<AchievementData *> *achievements;
@property(strong) NSMutableSet<NSNumber *> *unlockedAchievements;
@property(strong) NSDate *lastPomodoroDate;
@property(strong) NSMutableArray<SoundLayer *> *soundLayers;
@property(assign) BOOL isMiniPlayerActive;
@property(strong) EKEventStore *eventStore;
@property(assign) BOOL calendarEnabled;
@end

@implementation AppDelegate

- (instancetype)init {
  self = [super init];
  if (self) {
    _tasks = [NSMutableArray array];
    _records = [NSMutableArray array];
    _soundLayers = [NSMutableArray array];
    _achievements = [NSMutableArray array];
    _unlockedAchievements = [NSMutableSet set];
    _isWorkSession = YES;
    _isRunning = NO;
    _currentFocusMode = FocusModeClassic;
    _workDuration = 25 * 60;
    _breakDuration = 5 * 60;
    _longBreakDuration = 15 * 60;
    _totalSeconds = _workDuration;
    _remainingSeconds = _totalSeconds;
    _sessionCount = 0;
    _totalPomodorosAllTime = 0;
    _currentStreak = 0;
    _longestStreak = 0;
    _xpPoints = 0;
    _userLevel = 1;
    _isMiniPlayerActive = NO;
    _taskCountLabel = nil;
    _calendarEnabled = NO;
    [self setupFocusModes];
    [self setupAchievements];
    [self setupSoundLayers];
  }
  return self;
}

#pragma mark - Focus Modes Setup (#14)
- (void)setupFocusModes {
  // Mode configs are handled via FocusMode enum
}

- (FocusModeConfig *)configForMode:(FocusMode)mode {
  FocusModeConfig *config = [[FocusModeConfig alloc] init];
  switch (mode) {
    case FocusModeClassic:
      config.name = @"Classic Pomodoro";
      config.workDuration = 25 * 60;
      config.breakDuration = 5 * 60;
      config.longBreakDuration = 15 * 60;
      config.sessionsBeforeLongBreak = 4;
      config.autoStartNext = NO;
      config.enableDND = NO;
      break;
    case FocusModeDeepWork:
      config.name = @"Deep Work";
      config.workDuration = 90 * 60;
      config.breakDuration = 20 * 60;
      config.longBreakDuration = 30 * 60;
      config.sessionsBeforeLongBreak = 2;
      config.autoStartNext = YES;
      config.enableDND = YES;
      break;
    case FocusModeTimebox:
      config.name = @"Timeboxing";
      config.workDuration = 50 * 60;
      config.breakDuration = 10 * 60;
      config.longBreakDuration = 30 * 60;
      config.sessionsBeforeLongBreak = 3;
      config.autoStartNext = YES;
      config.enableDND = YES;
      break;
    case FocusModeSpicy:
      config.name = @"Spicy Mode";
      config.workDuration = 25 * 60;
      config.breakDuration = 5 * 60;
      config.longBreakDuration = 10 * 60;
      config.sessionsBeforeLongBreak = 4;
      config.autoStartNext = NO;
      config.enableDND = NO;
      break;
    case FocusModeMarathon:
      config.name = @"Marathon";
      config.workDuration = 60 * 60;
      config.breakDuration = 10 * 60;
      config.longBreakDuration = 30 * 60;
      config.sessionsBeforeLongBreak = 4;
      config.autoStartNext = YES;
      config.enableDND = YES;
      break;
  }
  return config;
}

#pragma mark - Achievements Setup (#11)
- (void)setupAchievements {
  [self.achievements addObject:[[AchievementData alloc] initWithType:AchievementFirstPomodoro title:@"First Step" desc:@"Complete your first pomodoro" xp:10]];
  [self.achievements addObject:[[AchievementData alloc] initWithType:AchievementDailyStreak3 title:@"Getting Started" desc:@"3-day streak" xp:50]];
  [self.achievements addObject:[[AchievementData alloc] initWithType:AchievementDailyStreak7 title:@"Week Warrior" desc:@"7-day streak" xp:150]];
  [self.achievements addObject:[[AchievementData alloc] initWithType:AchievementDailyStreak30 title:@"Monthly Master" desc:@"30-day streak" xp:1000]];
  [self.achievements addObject:[[AchievementData alloc] initWithType:Achievement10Pomodoros title:@"Getting Warmed Up" desc:@"Complete 10 pomodoros" xp:100]];
  [self.achievements addObject:[[AchievementData alloc] initWithType:Achievement50Pomodoros title:@"Half Century" desc:@"Complete 50 pomodoros" xp:500]];
  [self.achievements addObject:[[AchievementData alloc] initWithType:Achievement100Pomodoros title:@"Century Club" desc:@"Complete 100 pomodoros" xp:1000]];
  [self.achievements addObject:[[AchievementData alloc] initWithType:AchievementEarlyBird title:@"Early Bird" desc:@"Complete a pomodoro before 8 AM" xp:75]];
  [self.achievements addObject:[[AchievementData alloc] initWithType:AchievementNightOwl title:@"Night Owl" desc:@"Complete a pomodoro after 10 PM" xp:75]];
  [self.achievements addObject:[[AchievementData alloc] initWithType:AchievementMarathon title:@"Marathon Runner" desc:@"Complete 4 pomodoros in one day" xp:200]];
  [self.achievements addObject:[[AchievementData alloc] initWithType:AchievementWeekWarrior title:@"Week Warrior" desc:@"Complete 35 pomodoros in a week" xp:500]];
}

#pragma mark - Sound Layers Setup (#12)
- (void)setupSoundLayers {
  NSArray *sounds = @[
    @{@"name": @"Rain", @"file": @"rain"},
    @{@"name": @"Forest", @"file": @"forest"},
    @{@"name": @"Cafe", @"file": @"cafe"},
    @{@"name": @"Ocean", @"file": @"ocean"},
    @{@"name": @"Fireplace", @"file": @"fireplace"},
    @{@"name": @"White Noise", @"file": @"whitenoise"}
  ];

  for (NSDictionary *s in sounds) {
    SoundLayer *layer = [[SoundLayer alloc] init];
    layer.name = s[@"name"];
    layer.filename = s[@"file"];
    layer.volume = 0.5;
    layer.isPlaying = NO;
    [self.soundLayers addObject:layer];
  }
}

- (NSString *)dataDirectory {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *appDir = [[paths firstObject] stringByAppendingPathComponent:@"PomodoroTimer"];
  [[NSFileManager defaultManager] createDirectoryAtPath:appDir withIntermediateDirectories:YES attributes:nil error:nil];
  return appDir;
}

- (void)saveData {
  NSMutableArray *taskData = [NSMutableArray array];
  for (PomodoroTask *task in self.tasks) {
    [taskData addObject:@{@"id": task.taskId ?: @"", @"title": task.title ?: @"", @"completed": @(task.isCompleted), @"pomodoros": @(task.pomodorosSpent)}];
  }
  NSData *json = [NSJSONSerialization dataWithJSONObject:taskData options:0 error:nil];
  [json writeToFile:[[self dataDirectory] stringByAppendingPathComponent:@"tasks.json"] atomically:YES];

  NSMutableArray *recordData = [NSMutableArray array];
  for (PomodoroRecord *rec in self.records) {
    [recordData addObject:@{@"date": @([rec.date timeIntervalSince1970]), @"work": @(rec.workSeconds), @"completed": @(rec.completedPomodoros)}];
  }
  NSData *rjson = [NSJSONSerialization dataWithJSONObject:recordData options:0 error:nil];
  [rjson writeToFile:[[self dataDirectory] stringByAppendingPathComponent:@"records.json"] atomically:YES];

  NSDictionary *gamificationData = @{
    @"streak": @(self.currentStreak),
    @"longestStreak": @(self.longestStreak),
    @"totalPomodoros": @(self.totalPomodorosAllTime),
    @"xp": @(self.xpPoints),
    @"level": @(self.userLevel),
    @"unlockedAchievements": [self.unlockedAchievements allObjects]
  };
  NSData *gjson = [NSJSONSerialization dataWithJSONObject:gamificationData options:0 error:nil];
  [gjson writeToFile:[[self dataDirectory] stringByAppendingPathComponent:@"gamification.json"] atomically:YES];

  [self syncToiCloud];
}

- (void)loadData {
  [self.tasks removeAllObjects];
  [self.records removeAllObjects];
  [self.unlockedAchievements removeAllObjects];

  NSString *taskPath = [[self dataDirectory] stringByAppendingPathComponent:@"tasks.json"];
  NSData *data = [NSData dataWithContentsOfFile:taskPath];
  if (data) {
    NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    for (NSDictionary *d in arr) {
      PomodoroTask *t = [[PomodoroTask alloc] init];
      t.taskId = d[@"id"] ?: [[NSUUID UUID] UUIDString];
      t.title = d[@"title"] ?: @"";
      t.isCompleted = [d[@"completed"] boolValue];
      t.pomodorosSpent = [d[@"pomodoros"] integerValue];
      [self.tasks addObject:t];
    }
  }

  NSString *recPath = [[self dataDirectory] stringByAppendingPathComponent:@"records.json"];
  NSData *rdata = [NSData dataWithContentsOfFile:recPath];
  if (rdata) {
    NSArray *arr = [NSJSONSerialization JSONObjectWithData:rdata options:0 error:nil];
    for (NSDictionary *d in arr) {
      PomodoroRecord *r = [[PomodoroRecord alloc] init];
      r.date = [NSDate dateWithTimeIntervalSince1970:[d[@"date"] doubleValue]];
      r.workSeconds = [d[@"work"] integerValue];
      r.completedPomodoros = [d[@"completed"] integerValue];
      [self.records addObject:r];
    }
  }

  NSString *gamePath = [[self dataDirectory] stringByAppendingPathComponent:@"gamification.json"];
  NSData *gdata = [NSData dataWithContentsOfFile:gamePath];
  if (gdata) {
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:gdata options:0 error:nil];
    self.currentStreak = [dict[@"streak"] integerValue];
    self.longestStreak = [dict[@"longestStreak"] integerValue];
    self.totalPomodorosAllTime = [dict[@"totalPomodoros"] integerValue];
    self.xpPoints = [dict[@"xp"] integerValue];
    self.userLevel = [dict[@"level"] integerValue];
    for (id ach in dict[@"unlockedAchievements"]) {
      [self.unlockedAchievements addObject:ach];
    }
  }

  [self updateTodayStats];
  [self loadFromiCloud];
}

#pragma mark - iCloud Sync (#10)
- (void)syncToiCloud {
  NSUbiquitousKeyValueStore *store = [NSUbiquitousKeyValueStore defaultStore];
  NSDictionary *syncData = @{
    @"lastSync": @([[NSDate date] timeIntervalSince1970]),
    @"streak": @(self.currentStreak),
    @"totalPomodoros": @(self.totalPomodorosAllTime),
    @"xp": @(self.xpPoints)
  };
  [store setObject:syncData forKey:@"pomodoroData"];
  [store synchronize];
}

- (void)loadFromiCloud {
  NSUbiquitousKeyValueStore *store = [NSUbiquitousKeyValueStore defaultStore];
  NSDictionary *cloudData = [store objectForKey:@"pomodoroData"];
  if (cloudData) {
    NSLog(@"iCloud data available for sync");
  }
}

#pragma mark - Gamification (#11)
- (void)checkAchievements {
  NSCalendar *cal = [NSCalendar currentCalendar];
  NSDate *now = [NSDate date];

  if (self.todayCompletedPomodoros >= 1 && ![self.unlockedAchievements containsObject:@(AchievementFirstPomodoro)]) {
    [self unlockAchievement:AchievementFirstPomodoro];
  }

  NSInteger hour = [cal component:NSCalendarUnitHour fromDate:now];
  if (hour < 8 && self.todayCompletedPomodoros >= 1 && ![self.unlockedAchievements containsObject:@(AchievementEarlyBird)]) {
    [self unlockAchievement:AchievementEarlyBird];
  }
  if (hour >= 22 && self.todayCompletedPomodoros >= 1 && ![self.unlockedAchievements containsObject:@(AchievementNightOwl)]) {
    [self unlockAchievement:AchievementNightOwl];
  }

  if (self.todayCompletedPomodoros >= 4 && ![self.unlockedAchievements containsObject:@(AchievementMarathon)]) {
    [self unlockAchievement:AchievementMarathon];
  }

  if (self.totalPomodorosAllTime >= 10 && ![self.unlockedAchievements containsObject:@(Achievement10Pomodoros)]) {
    [self unlockAchievement:Achievement10Pomodoros];
  }
  if (self.totalPomodorosAllTime >= 50 && ![self.unlockedAchievements containsObject:@(Achievement50Pomodoros)]) {
    [self unlockAchievement:Achievement50Pomodoros];
  }
  if (self.totalPomodorosAllTime >= 100 && ![self.unlockedAchievements containsObject:@(Achievement100Pomodoros)]) {
    [self unlockAchievement:Achievement100Pomodoros];
  }

  [self checkStreakAchievements];
  [self updateUserLevel];
}

- (void)checkStreakAchievements {
  if (self.currentStreak >= 3 && ![self.unlockedAchievements containsObject:@(AchievementDailyStreak3)]) {
    [self unlockAchievement:AchievementDailyStreak3];
  }
  if (self.currentStreak >= 7 && ![self.unlockedAchievements containsObject:@(AchievementDailyStreak7)]) {
    [self unlockAchievement:AchievementDailyStreak7];
  }
  if (self.currentStreak >= 30 && ![self.unlockedAchievements containsObject:@(AchievementDailyStreak30)]) {
    [self unlockAchievement:AchievementDailyStreak30];
  }
}

- (void)unlockAchievement:(Achievement)achievement {
  if ([self.unlockedAchievements containsObject:@(achievement)]) return;

  [self.unlockedAchievements addObject:@(achievement)];

  AchievementData *data = nil;
  for (AchievementData *a in self.achievements) {
    if (a.type == achievement) { data = a; break; }
  }

  if (data) {
    self.xpPoints += data.xpReward;
    data.unlocked = YES;
    data.unlockedDate = [NSDate date];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"🏆 Achievement Unlocked: %@", data.title];
    alert.informativeText = [NSString stringWithFormat:@"%@\n+%ld XP", data.achievedDescription, (long)data.xpReward];
    [alert addButtonWithTitle:@"Awesome!"];
    [alert runModal];
  }

  [self saveData];
}

- (void)updateUserLevel {
  NSInteger newLevel = (NSInteger)(sqrt(self.xpPoints / 100.0)) + 1;
  if (newLevel > self.userLevel) {
    self.userLevel = newLevel;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"🎉 Level Up! You're now level %ld", (long)newLevel];
    alert.informativeText = @"Keep up the great work!";
    [alert addButtonWithTitle:@"Thanks!"];
    [alert runModal];
  }
}

- (void)updateStreak {
  NSCalendar *cal = [NSCalendar currentCalendar];
  NSDate *today = [cal startOfDayForDate:[NSDate date]];

  if (self.lastPomodoroDate) {
    NSDate *lastDay = [cal startOfDayForDate:self.lastPomodoroDate];
    NSTimeInterval interval = [today timeIntervalSinceDate:lastDay];
    NSInteger days = (NSInteger)(interval / 86400);

    if (days == 1) {
      self.currentStreak++;
    } else if (days > 1) {
      self.currentStreak = 1;
    }
  } else {
    self.currentStreak = 1;
  }

  if (self.currentStreak > self.longestStreak) {
    self.longestStreak = self.currentStreak;
  }

  self.lastPomodoroDate = [NSDate date];
}

#pragma mark - Calendar Integration (#13)
- (void)requestCalendarAccess {
  if (!self.eventStore) {
    self.eventStore = [[EKEventStore alloc] init];
  }
  if (@available(macOS 14.0, *)) {
    [self.eventStore requestFullAccessToEventsWithCompletion:^(BOOL granted, NSError *error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        self.calendarEnabled = granted;
        if (!granted) {
          NSLog(@"Calendar access denied: %@", error.localizedDescription);
        }
      });
    }];
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self.eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
#pragma clang diagnostic pop
      dispatch_async(dispatch_get_main_queue(), ^{
        self.calendarEnabled = granted;
        if (!granted) {
          NSLog(@"Calendar access denied");
        }
      });
    }];
  }
}

- (void)addCalendarEvent:(NSString *)title duration:(NSInteger)seconds {
  if (!self.calendarEnabled || !self.eventStore) return;

  EKEvent *event = [EKEvent eventWithEventStore:self.eventStore];
  event.title = [NSString stringWithFormat:@"🍅 Pomodoro: %@", title];
  event.startDate = [NSDate date];
  event.endDate = [NSDate dateWithTimeIntervalSinceNow:seconds];
  event.calendar = [self.eventStore defaultCalendarForNewEvents];

  NSError *error = nil;
  [self.eventStore saveEvent:event span:EKSpanThisEvent commit:YES error:&error];
  if (error) {
    NSLog(@"Failed to save calendar event: %@", error);
  }
}

#pragma mark - Do Not Disturb (#18)
- (void)enableDND {
  if (@available(macOS 15.0, *)) {
    NSLog(@"Focus API integration would go here on macOS 15+");
  }
}

- (void)disableDND {
  if (@available(macOS 15.0, *)) {
    NSLog(@"Focus API disable would go here");
  }
}

#pragma mark - Analytics (#17)
- (NSDictionary *)getWeeklyStats {
  NSCalendar *cal = [NSCalendar currentCalendar];
  NSMutableDictionary *stats = [NSMutableDictionary dictionary];
  NSInteger totalPomodoros = 0;
  NSInteger totalMinutes = 0;

  for (NSInteger i = 0; i < 7; i++) {
    NSDate *day = [cal dateByAddingUnit:NSCalendarUnitDay value:-i toDate:[NSDate date] options:0];
    NSDate *startOfDay = [cal startOfDayForDate:day];

    NSInteger dayPomos = 0;
    NSInteger dayMinutes = 0;

    for (PomodoroRecord *rec in self.records) {
      if ([cal isDate:rec.date inSameDayAsDate:startOfDay]) {
        dayPomos = rec.completedPomodoros;
        dayMinutes = rec.workSeconds / 60;
        break;
      }
    }

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"EEE";
    NSString *dayName = [df stringFromDate:day];
    stats[dayName] = @{@"pomodoros": @(dayPomos), @"minutes": @(dayMinutes)};

    totalPomodoros += dayPomos;
    totalMinutes += dayMinutes;
  }

  stats[@"total"] = @{@"pomodoros": @(totalPomodoros), @"minutes": @(totalMinutes)};
  return stats;
}

- (NSInteger)getHeatmapValueForDay:(NSDate *)date {
  NSCalendar *cal = [NSCalendar currentCalendar];
  for (PomodoroRecord *rec in self.records) {
    if ([cal isDate:rec.date inSameDayAsDate:date]) {
      return rec.completedPomodoros;
    }
  }
  return 0;
}

#pragma mark - App Launch
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  [self loadData];
  [self setupWindow];
  [self setupMenuBar];
  [self setupStatusBar];
  [self setupSoundWithType:SoundTypeWork];
  [self requestCalendarAccess];

  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound) completionHandler:^(BOOL g, NSError *e) {}];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appearanceChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iCloudChanged:) name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification object:nil];
}

- (void)iCloudChanged:(NSNotification *)n {
  [self loadFromiCloud];
}

- (void)appearanceChanged:(NSNotification *)n {
  NSLog(@"Theme changed: %@", [NSApp effectiveAppearance].name);
}

#pragma mark - Window Setup
- (void)setupWindow {
  self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(400, 300, 500, 680)
                                            styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
                                              backing:NSBackingStoreBuffered defer:NO];
  self.window.title = @"Pomodoro Timer";
  self.window.minSize = NSMakeSize(450, 650);
  [self.window center];
  [self.window makeKeyAndOrderFront:nil];

  NSVisualEffectView *bg = [[NSVisualEffectView alloc] initWithFrame:self.window.contentView.bounds];
  bg.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  bg.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  bg.material = NSVisualEffectMaterialHUDWindow;
  bg.state = NSVisualEffectStateActive;
  [self.window.contentView addSubview:bg];

  [self setupMainContent];
}

- (void)setupMainContent {
  NSView *content = self.window.contentView;

  NSVisualEffectView *headerBar = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 635, 500, 35)];
  headerBar.material = NSVisualEffectMaterialTitlebar;
  headerBar.wantsLayer = YES;
  [content addSubview:headerBar];

  NSTextField *streakLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"🔥 %ldd  🏆 L%ld  ✨%ldXP", (long)self.currentStreak, (long)self.userLevel, (long)self.xpPoints]];
  streakLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
  streakLabel.textColor = [NSColor secondaryLabelColor];
  streakLabel.frame = NSMakeRect(20, 8, 460, 20);
  [headerBar addSubview:streakLabel];

  NSVisualEffectView *timerBox = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(40, 450, 420, 170)];
  timerBox.material = NSVisualEffectMaterialHUDWindow;
  timerBox.wantsLayer = YES;
  timerBox.layer.cornerRadius = 24;
  timerBox.state = NSVisualEffectStateActive;
  timerBox.alphaValue = 0.9;
  [content addSubview:timerBox];

  NSString *modeName = [self configForMode:self.currentFocusMode].name;
  NSTextField *modeLabel = [NSTextField labelWithString:modeName];
  modeLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
  modeLabel.textColor = [NSColor secondaryLabelColor];
  modeLabel.alignment = NSTextAlignmentCenter;
  modeLabel.frame = NSMakeRect(20, 142, 380, 18);
  [timerBox addSubview:modeLabel];

  self.timeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 55, 420, 85)];
  self.timeLabel.stringValue = [self formatTime:self.remainingSeconds];
  self.timeLabel.font = [NSFont monospacedDigitSystemFontOfSize:64 weight:NSFontWeightMedium];
  self.timeLabel.textColor = [NSColor labelColor];
  self.timeLabel.bezeled = NO;
  self.timeLabel.drawsBackground = NO;
  self.timeLabel.editable = NO;
  self.timeLabel.selectable = NO;
  self.timeLabel.alignment = NSTextAlignmentCenter;
  [timerBox addSubview:self.timeLabel];

  self.progressBar = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(60, 30, 300, 10)];
  self.progressBar.indeterminate = NO;
  self.progressBar.minValue = 0;
  self.progressBar.maxValue = self.totalSeconds;
  self.progressBar.doubleValue = self.remainingSeconds;
  self.progressBar.wantsLayer = YES;
  self.progressBar.layer.cornerRadius = 5;
  [timerBox addSubview:self.progressBar];

  NSStackView *btnStack = [[NSStackView alloc] initWithFrame:NSMakeRect(40, 405, 420, 38)];
  btnStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  btnStack.spacing = 12;
  btnStack.distribution = NSStackViewDistributionFillEqually;
  [content addSubview:btnStack];

  self.startButton = [NSButton buttonWithTitle:@"▶  Start" target:self action:@selector(startPauseToggle)];
  self.startButton.bezelStyle = NSBezelStyleRounded;
  self.startButton.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
  self.startButton.tag = 300;
  [btnStack addArrangedSubview:self.startButton];

  self.pauseButton = nil;

  self.resetButton = [NSButton buttonWithTitle:@"↺  Reset" target:self action:@selector(resetTimer)];
  self.resetButton.bezelStyle = NSBezelStyleRounded;
  self.resetButton.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
  [btnStack addArrangedSubview:self.resetButton];

  NSButton *miniPlayerBtn = [NSButton buttonWithTitle:@"◻  Mini" target:self action:@selector(toggleMiniPlayer)];
  miniPlayerBtn.bezelStyle = NSBezelStyleRounded;
  miniPlayerBtn.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
  [btnStack addArrangedSubview:miniPlayerBtn];

  NSBox *statsBox = [[NSBox alloc] initWithFrame:NSMakeRect(40, 280, 420, 115)];
  statsBox.boxType = NSBoxCustom;
  statsBox.cornerRadius = 20;
  statsBox.fillColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.5];
  statsBox.borderWidth = 0;
  [content addSubview:statsBox];

  NSTextField *statsTitle = [NSTextField labelWithString:@"Today's Progress"];
  statsTitle.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
  statsTitle.frame = NSMakeRect(20, 82, 200, 22);
  [statsBox.contentView addSubview:statsTitle];

  NSBox *pomoStatBox = [[NSBox alloc] initWithFrame:NSMakeRect(20, 30, 120, 45)];
  pomoStatBox.boxType = NSBoxCustom;
  pomoStatBox.cornerRadius = 12;
  pomoStatBox.fillColor = [[NSColor systemOrangeColor] colorWithAlphaComponent:0.2];
  pomoStatBox.borderWidth = 0;
  [statsBox.contentView addSubview:pomoStatBox];

  NSTextField *pomoIcon = [NSTextField labelWithString:@"🍅"];
  pomoIcon.frame = NSMakeRect(10, 10, 28, 28);
  pomoIcon.font = [NSFont systemFontOfSize:22];
  [pomoStatBox.contentView addSubview:pomoIcon];

  NSTextField *pomCount = [NSTextField labelWithString:[NSString stringWithFormat:@"%ld", (long)self.todayCompletedPomodoros]];
  pomCount.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
  pomCount.textColor = [NSColor systemOrangeColor];
  pomCount.frame = NSMakeRect(45, 10, 60, 28);
  pomCount.tag = 101;
  [pomoStatBox.contentView addSubview:pomCount];

  NSBox *timeStatBox = [[NSBox alloc] initWithFrame:NSMakeRect(150, 30, 120, 45)];
  timeStatBox.boxType = NSBoxCustom;
  timeStatBox.cornerRadius = 12;
  timeStatBox.fillColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.2];
  timeStatBox.borderWidth = 0;
  [statsBox.contentView addSubview:timeStatBox];

  NSTextField *timeIcon = [NSTextField labelWithString:@"⏱"];
  timeIcon.frame = NSMakeRect(10, 10, 28, 28);
  timeIcon.font = [NSFont systemFontOfSize:20];
  [timeStatBox.contentView addSubview:timeIcon];

  NSTextField *timeCount = [NSTextField labelWithString:[NSString stringWithFormat:@"%ldm", (long)(self.todayWorkSeconds / 60)]];
  timeCount.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
  timeCount.textColor = [NSColor systemBlueColor];
  timeCount.frame = NSMakeRect(45, 10, 70, 28);
  timeCount.tag = 102;
  [timeStatBox.contentView addSubview:timeCount];

  NSBox *streakBox = [[NSBox alloc] initWithFrame:NSMakeRect(280, 30, 120, 45)];
  streakBox.boxType = NSBoxCustom;
  streakBox.cornerRadius = 12;
  streakBox.fillColor = [[NSColor systemRedColor] colorWithAlphaComponent:0.2];
  streakBox.borderWidth = 0;
  [statsBox.contentView addSubview:streakBox];

  NSTextField *streakIcon = [NSTextField labelWithString:@"🔥"];
  streakIcon.frame = NSMakeRect(10, 10, 28, 28);
  streakIcon.font = [NSFont systemFontOfSize:20];
  [streakBox.contentView addSubview:streakIcon];

  NSTextField *streakCount = [NSTextField labelWithString:[NSString stringWithFormat:@"%ldd", (long)self.currentStreak]];
  streakCount.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
  streakCount.textColor = [NSColor systemRedColor];
  streakCount.frame = NSMakeRect(45, 10, 60, 28);
  [streakBox.contentView addSubview:streakCount];

  NSBox *tasksBox = [[NSBox alloc] initWithFrame:NSMakeRect(40, 35, 420, 235)];
  tasksBox.boxType = NSBoxCustom;
  tasksBox.cornerRadius = 20;
  tasksBox.fillColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.5];
  tasksBox.borderWidth = 0;
  [content addSubview:tasksBox];

  NSTextField *tasksTitle = [NSTextField labelWithString:@"Tasks"];
  tasksTitle.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
  tasksTitle.frame = NSMakeRect(20, 200, 80, 22);
  [tasksBox.contentView addSubview:tasksTitle];

  self.taskCountLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"%ld items", (long)self.tasks.count]];
  self.taskCountLabel.font = [NSFont systemFontOfSize:12];
  self.taskCountLabel.textColor = [NSColor secondaryLabelColor];
  self.taskCountLabel.frame = NSMakeRect(90, 203, 100, 18);
  [tasksBox.contentView addSubview:self.taskCountLabel];

  NSButton *quickAddBtn = [NSButton buttonWithTitle:@"+ Add" target:self action:@selector(addTask)];
  quickAddBtn.bezelStyle = NSBezelStyleRounded;
  quickAddBtn.frame = NSMakeRect(345, 198, 60, 26);
  quickAddBtn.controlSize = NSControlSizeSmall;
  [tasksBox.contentView addSubview:quickAddBtn];

  NSScrollView *taskScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 40, 400, 150)];
  taskScroll.hasVerticalScroller = YES;
  taskScroll.autohidesScrollers = YES;
  taskScroll.borderType = NSNoBorder;
  [tasksBox.contentView addSubview:taskScroll];

  self.taskTableView = [[NSTableView alloc] init];
  self.taskTableView.delegate = self;
  self.taskTableView.dataSource = self;
  self.taskTableView.rowHeight = 40;
  self.taskTableView.usesAlternatingRowBackgroundColors = NO;
  self.taskTableView.backgroundColor = [NSColor clearColor];

  NSTableColumn *checkCol = [[NSTableColumn alloc] initWithIdentifier:@"done"];
  checkCol.width = 35;
  [self.taskTableView addTableColumn:checkCol];

  NSTableColumn *titleCol = [[NSTableColumn alloc] initWithIdentifier:@"title"];
  titleCol.width = 270;
  [self.taskTableView addTableColumn:titleCol];

  NSTableColumn *pomoCol = [[NSTableColumn alloc] initWithIdentifier:@"pomodoros"];
  pomoCol.width = 80;
  [self.taskTableView addTableColumn:pomoCol];

  taskScroll.documentView = self.taskTableView;

  NSStackView *taskActions = [[NSStackView alloc] initWithFrame:NSMakeRect(20, 8, 380, 24)];
  taskActions.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  taskActions.spacing = 6;

  NSButton *cAll = [NSButton buttonWithTitle:@"✓ All" target:self action:@selector(checkAllCompleted)];
  cAll.bezelStyle = NSBezelStyleInline;
  cAll.font = [NSFont systemFontOfSize:10];
  [taskActions addArrangedSubview:cAll];

  NSButton *uAll = [NSButton buttonWithTitle:@"✗ Clear" target:self action:@selector(uncheckAll)];
  uAll.bezelStyle = NSBezelStyleInline;
  uAll.font = [NSFont systemFontOfSize:10];
  [taskActions addArrangedSubview:uAll];

  NSButton *delSel = [NSButton buttonWithTitle:@"🗑 Delete" target:self action:@selector(deleteTaskFromMain)];
  delSel.bezelStyle = NSBezelStyleInline;
  delSel.font = [NSFont systemFontOfSize:10];
  [taskActions addArrangedSubview:delSel];

  NSButton *clearDone = [NSButton buttonWithTitle:@"Remove Done" target:self action:@selector(deleteCompletedTasks)];
  clearDone.bezelStyle = NSBezelStyleInline;
  clearDone.font = [NSFont systemFontOfSize:10];
  [taskActions addArrangedSubview:clearDone];

  [tasksBox.contentView addSubview:taskActions];

  [self updateStatsDisplay];
}

#pragma mark - Mini Player (#19)
- (void)toggleMiniPlayer {
  if (self.isMiniPlayerActive) {
    [self.miniPlayerWindow close];
    self.isMiniPlayerActive = NO;
    [self.window makeKeyAndOrderFront:nil];
  } else {
    [self.window orderOut:nil];
    [self createMiniPlayer];
    self.isMiniPlayerActive = YES;
  }
}

- (void)createMiniPlayer {
  self.miniPlayerWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(100, 100, 200, 50)
                                                   styleMask:(NSWindowStyleMaskBorderless)
                                                     backing:NSBackingStoreBuffered defer:NO];
  self.miniPlayerWindow.level = NSStatusWindowLevel;
  [self.miniPlayerWindow setOpaque:NO];
  self.miniPlayerWindow.backgroundColor = [NSColor clearColor];
  self.miniPlayerWindow.hasShadow = YES;

  NSVisualEffectView *bg = [[NSVisualEffectView alloc] initWithFrame:self.miniPlayerWindow.contentView.bounds];
  bg.material = NSVisualEffectMaterialHUDWindow;
  bg.state = NSVisualEffectStateActive;
  bg.wantsLayer = YES;
  bg.layer.cornerRadius = 12;
  bg.layer.masksToBounds = YES;
  [self.miniPlayerWindow.contentView addSubview:bg];

  NSTextField *miniTime = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 100, 30)];
  miniTime.stringValue = [self formatTime:self.remainingSeconds];
  miniTime.font = [NSFont monospacedDigitSystemFontOfSize:20 weight:NSFontWeightMedium];
  miniTime.bezeled = NO;
  miniTime.drawsBackground = NO;
  miniTime.editable = NO;
  miniTime.selectable = NO;
  miniTime.tag = 201;
  [bg addSubview:miniTime];

  NSStackView *miniBtnStack = [[NSStackView alloc] initWithFrame:NSMakeRect(110, 10, 80, 30)];
  miniBtnStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  miniBtnStack.spacing = 4;

  NSButton *miniStartPause = [NSButton buttonWithTitle:@"▶" target:self action:@selector(miniPlayPause)];
  miniStartPause.bezelStyle = NSBezelStyleCircular;
  miniStartPause.tag = 202;
  miniStartPause.toolTip = @"Start/Pause";
  [miniBtnStack addArrangedSubview:miniStartPause];

  NSButton *miniClose = [NSButton buttonWithTitle:@"✕" target:self action:@selector(toggleMiniPlayer)];
  miniClose.bezelStyle = NSBezelStyleCircular;
  [miniBtnStack addArrangedSubview:miniClose];

  [bg addSubview:miniBtnStack];

  [self.miniPlayerWindow makeKeyAndOrderFront:nil];

  [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDragged handler:^(NSEvent *e) {
    NSPoint p = [NSEvent mouseLocation];
    [self.miniPlayerWindow setFrame:NSMakeRect(p.x - 100, p.y - 25, 200, 50) display:YES];
  }];
}

- (void)updateMiniPlayer {
  if (self.isMiniPlayerActive && self.miniPlayerWindow) {
    NSTextField *miniTime = [self.miniPlayerWindow.contentView viewWithTag:201];
    if (miniTime) miniTime.stringValue = [self formatTime:self.remainingSeconds];
    NSButton *btn = [self.miniPlayerWindow.contentView viewWithTag:202];
    if (btn) {
      btn.title = self.isRunning ? @"⏸" : @"▶";
      btn.toolTip = self.isRunning ? @"Pause" : @"Start";
    }
  }
}

- (void)miniPlayPause {
  if (self.isRunning) {
    [self pauseTimer];
  } else {
    [self startTimer];
  }
}

#pragma mark - Menu Bar
- (void)setupMenuBar {
  NSMenu *menu = [[NSMenu alloc] init];

  NSMenuItem *pomodoroItem = [[NSMenuItem alloc] initWithTitle:@"Pomodoro" action:nil keyEquivalent:@""];
  NSMenu *pomodoroMenu = [[NSMenu alloc] initWithTitle:@"Pomodoro"];
  [pomodoroMenu addItem:[[NSMenuItem alloc] initWithTitle:@"About Pomodoro Timer" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""]];
  [pomodoroMenu addItem:[NSMenuItem separatorItem]];

  NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"Settings..." action:@selector(openSettings) keyEquivalent:@","];
  [settingsItem setTarget:self];
  if (@available(macOS 11.0, *)) settingsItem.image = [NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:@"Settings"];
  [pomodoroMenu addItem:settingsItem];

  NSMenuItem *focusModesItem = [[NSMenuItem alloc] initWithTitle:@"Focus Modes" action:nil keyEquivalent:@""];
  NSMenu *focusMenu = [[NSMenu alloc] initWithTitle:@"Focus Modes"];
  [focusMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Classic Pomodoro (25/5)" action:@selector(setModeClassic) keyEquivalent:@""]];
  [focusMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Deep Work (90/20)" action:@selector(setModeDeepWork) keyEquivalent:@""]];
  [focusMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Timeboxing (50/10)" action:@selector(setModeTimebox) keyEquivalent:@""]];
  [focusMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Spicy Mode" action:@selector(setModeSpicy) keyEquivalent:@""]];
  [focusMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Marathon (60/10)" action:@selector(setModeMarathon) keyEquivalent:@""]];
  [focusModesItem setSubmenu:focusMenu];
  [pomodoroMenu addItem:focusModesItem];

  [pomodoroMenu addItem:[NSMenuItem separatorItem]];

  NSMenuItem *analyticsItem = [[NSMenuItem alloc] initWithTitle:@"Analytics..." action:@selector(openAnalytics) keyEquivalent:@"a"];
  [analyticsItem setTarget:self];
  if (@available(macOS 11.0, *)) analyticsItem.image = [NSImage imageWithSystemSymbolName:@"chart.bar.fill" accessibilityDescription:@"Analytics"];
  [pomodoroMenu addItem:analyticsItem];

  NSMenuItem *achievementsItem = [[NSMenuItem alloc] initWithTitle:@"Achievements..." action:@selector(openAchievements) keyEquivalent:@""];
  [achievementsItem setTarget:self];
  if (@available(macOS 11.0, *)) achievementsItem.image = [NSImage imageWithSystemSymbolName:@"trophy.fill" accessibilityDescription:@"Achievements"];
  [pomodoroMenu addItem:achievementsItem];

  [pomodoroMenu addItem:[NSMenuItem separatorItem]];

  NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Pomodoro" action:@selector(terminate:) keyEquivalent:@"q"];
  [pomodoroItem setSubmenu:pomodoroMenu];
  [menu addItem:pomodoroItem];

  NSMenuItem *timerItem = [[NSMenuItem alloc] initWithTitle:@"Timer" action:nil keyEquivalent:@""];
  NSMenu *timerMenu = [[NSMenu alloc] initWithTitle:@"Timer"];
  [timerMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Start" action:@selector(startTimer) keyEquivalent:@"s"]];
  [timerMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Pause" action:@selector(pauseTimer) keyEquivalent:@"p"]];
  [timerMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Reset" action:@selector(resetTimer) keyEquivalent:@"r"]];
  [timerMenu addItem:[NSMenuItem separatorItem]];
  [timerMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Mini Player" action:@selector(toggleMiniPlayer) keyEquivalent:@"m"]];
  [timerItem setSubmenu:timerMenu];
  [menu addItem:timerItem];

  NSMenuItem *tasksItem = [[NSMenuItem alloc] initWithTitle:@"Tasks" action:nil keyEquivalent:@""];
  NSMenu *tasksMenu = [[NSMenu alloc] initWithTitle:@"Tasks"];
  [tasksMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Add Task..." action:@selector(addTask) keyEquivalent:@"t"]];
  [tasksMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Delete Selected Task" action:@selector(deleteTask) keyEquivalent:@""]];
  [tasksMenu addItem:[NSMenuItem separatorItem]];
  [tasksMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Check All Completed" action:@selector(checkAllCompleted) keyEquivalent:@""]];
  [tasksMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Uncheck All" action:@selector(uncheckAll) keyEquivalent:@""]];
  [tasksMenu addItem:[NSMenuItem separatorItem]];
  [tasksMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Delete Completed Tasks" action:@selector(deleteCompletedTasks) keyEquivalent:@""]];
  [tasksMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Delete All Tasks" action:@selector(deleteAllTasks) keyEquivalent:@""]];
  [tasksItem setSubmenu:tasksMenu];
  [menu addItem:tasksItem];

  NSMenuItem *musicItem = [[NSMenuItem alloc] initWithTitle:@"Music" action:nil keyEquivalent:@""];
  NSMenu *musicMenu = [[NSMenu alloc] initWithTitle:@"Music"];
  [musicMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Sound Mixer..." action:@selector(openMusicMixer) keyEquivalent:@""]];
  [musicMenu addItem:[NSMenuItem separatorItem]];
  for (SoundLayer *layer in self.soundLayers) {
    NSMenuItem *s = [[NSMenuItem alloc] initWithTitle:layer.name action:@selector(toggleSoundByName:) keyEquivalent:@""];
    s.target = self;
    s.representedObject = layer.name;
    [musicMenu addItem:s];
  }
  [musicItem setSubmenu:musicMenu];
  [menu addItem:musicItem];

  NSMenuItem *calendarItem = [[NSMenuItem alloc] initWithTitle:@"Calendar" action:nil keyEquivalent:@""];
  NSMenu *calMenu = [[NSMenu alloc] initWithTitle:@"Calendar"];
  [calMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Sync to Calendar" action:@selector(toggleCalendarSync) keyEquivalent:@""]];
  [calendarItem setSubmenu:calMenu];
  [menu addItem:calendarItem];

  [NSApp setMainMenu:menu];
}

- (void)setModeClassic { [self setFocusMode:FocusModeClassic]; }
- (void)setModeDeepWork { [self setFocusMode:FocusModeDeepWork]; }
- (void)setModeTimebox { [self setFocusMode:FocusModeTimebox]; }
- (void)setModeSpicy { [self setFocusMode:FocusModeSpicy]; }
- (void)setModeMarathon { [self setFocusMode:FocusModeMarathon]; }

- (void)setFocusMode:(FocusMode)mode {
  FocusModeConfig *config = [self configForMode:mode];
  self.currentFocusMode = mode;
  self.workDuration = config.workDuration;
  self.breakDuration = config.breakDuration;
  self.longBreakDuration = config.longBreakDuration;
  self.sessionCount = 0;
  [self resetTimer];

  if (config.enableDND) {
    [self enableDND];
  } else {
    [self disableDND];
  }
}

#pragma mark - Status Bar
- (void)setupStatusBar {
  self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

  if (@available(macOS 11.0, *)) {
    NSImage *img = [NSImage imageWithSystemSymbolName:@"timer" accessibilityDescription:@"Pomodoro"];
    img = [img imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium]];
    self.statusItem.button.image = img;
  }

  NSMenu *m = [[NSMenu alloc] init];

  NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:@"🍅 Pomodoro Timer" action:nil keyEquivalent:@""];
  headerItem.enabled = NO;
  [m addItem:headerItem];
  [m addItem:[NSMenuItem separatorItem]];

  NSMenuItem *timerItem = [[NSMenuItem alloc] initWithTitle:@"25:00 — Work" action:nil keyEquivalent:@""];
  timerItem.tag = 999;
  [m addItem:timerItem];

  NSMenuItem *streakItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"🔥 Day %ld streak", (long)self.currentStreak] action:nil keyEquivalent:@""];
  streakItem.tag = 998;
  [m addItem:streakItem];

  [m addItem:[NSMenuItem separatorItem]];

  NSMenuItem *startItem = [[NSMenuItem alloc] initWithTitle:@"Start" action:@selector(startTimer) keyEquivalent:@"s"];
  [startItem setTarget:self];
  if (@available(macOS 11.0, *)) startItem.image = [NSImage imageWithSystemSymbolName:@"play.fill" accessibilityDescription:@"Start"];
  [m addItem:startItem];

  NSMenuItem *pauseItem = [[NSMenuItem alloc] initWithTitle:@"Pause" action:@selector(pauseTimer) keyEquivalent:@"p"];
  [pauseItem setTarget:self];
  if (@available(macOS 11.0, *)) pauseItem.image = [NSImage imageWithSystemSymbolName:@"pause.fill" accessibilityDescription:@"Pause"];
  [m addItem:pauseItem];

  NSMenuItem *resetItem = [[NSMenuItem alloc] initWithTitle:@"Reset" action:@selector(resetTimer) keyEquivalent:@"r"];
  [resetItem setTarget:self];
  if (@available(macOS 11.0, *)) resetItem.image = [NSImage imageWithSystemSymbolName:@"arrow.counterclockwise" accessibilityDescription:@"Reset"];
  [m addItem:resetItem];

  [m addItem:[NSMenuItem separatorItem]];

  NSMenuItem *miniItem = [[NSMenuItem alloc] initWithTitle:@"Mini Player" action:@selector(toggleMiniPlayer) keyEquivalent:@"m"];
  [miniItem setTarget:self];
  [m addItem:miniItem];

  NSMenuItem *analyticsItem = [[NSMenuItem alloc] initWithTitle:@"Analytics" action:@selector(openAnalytics) keyEquivalent:@""];
  [analyticsItem setTarget:self];
  [m addItem:analyticsItem];

  [m addItem:[NSMenuItem separatorItem]];

  NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"Settings..." action:@selector(openSettings) keyEquivalent:@","];
  [settingsItem setTarget:self];
  if (@available(macOS 11.0, *)) settingsItem.image = [NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:@"Settings"];
  [m addItem:settingsItem];

  [m addItem:[NSMenuItem separatorItem]];

  NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
  [m addItem:quitItem];

  self.statusItem.menu = m;
  [self updateStatusBar];
}

- (void)updateStatusBar {
  NSString *type = self.isWorkSession ? @"Work" : @"Break";
  NSString *time = [self formatTime:self.remainingSeconds];
  self.statusItem.button.title = [NSString stringWithFormat:@" %@ ", time];

  NSMenuItem *timerItem = [self.statusItem.menu itemWithTag:999];
  if (timerItem) timerItem.title = [NSString stringWithFormat:@"%@ — %@", time, type];

  NSMenuItem *streakItem = [self.statusItem.menu itemWithTag:998];
  if (streakItem) streakItem.title = [NSString stringWithFormat:@"🔥 Day %ld streak", (long)self.currentStreak];

  if (@available(macOS 11.0, *)) {
    NSString *symbolName = self.isRunning ? @"play.circle.fill" : @"timer";
    NSImage *img = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:@"Timer"];
    img = [img imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium]];
    self.statusItem.button.image = img;
  }
}

#pragma mark - Timer
- (void)startPauseToggle {
  if (self.isRunning) {
    [self pauseTimer];
  } else {
    [self startTimer];
  }
}

- (void)startTimer {
  if (self.isRunning) return;
  if (self.timer) { [self.timer invalidate]; self.timer = nil; }
  self.isRunning = YES;
  if (self.startButton) self.startButton.title = @"⏸  Pause";
  if (!self.soundType) [self setupSoundWithType:SoundTypeWork];
  if (self.soundType && !self.soundType.playing) { self.soundType.volume = 1.0; [self.soundType play]; }
  self.timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
  [self updateUI];
}

- (void)pauseTimer {
  if (!self.isRunning) return;
  self.isRunning = NO;
  if (self.startButton) self.startButton.title = @"▶  Start";
  [self.timer invalidate]; self.timer = nil;
  if (self.soundType && self.soundType.playing) [self.soundType stop];
  [self updateUI];
}

- (void)resetTimer {
  [self pauseTimer];
  if (self.startButton) self.startButton.title = @"▶  Start";
  self.totalSeconds = self.isWorkSession ? self.workDuration : self.breakDuration;
  self.remainingSeconds = self.totalSeconds;
  [self.progressBar setMaxValue:self.totalSeconds];
  [self.progressBar setDoubleValue:self.remainingSeconds];
  [self.timeLabel setStringValue:[self formatTime:self.remainingSeconds]];
  [self updateUI];
}

- (void)tick {
  if (self.remainingSeconds > 0) {
    self.remainingSeconds--;
    [self updateUI];
    return;
  }
  [self.timer invalidate]; self.timer = nil;
  self.isRunning = NO;
  self.startButton.enabled = YES;
  self.pauseButton.enabled = NO;
  if (self.soundType.playing) [self.soundType stop];

  if (self.isWorkSession) {
    self.sessionCount++;
    [self recordPomodoro:self.workDuration];
    [self updateStreak];
    [self checkAchievements];
    [self switchToBreak];
  } else {
    [self switchToWork];
  }
  [self sendNotification];
}

- (void)switchToBreak {
  self.isWorkSession = NO;
  NSInteger breakTime = (self.sessionCount % 4 == 0) ? self.longBreakDuration : self.breakDuration;
  breakTime = breakTime ?: self.breakDuration;
  self.totalSeconds = breakTime;
  self.remainingSeconds = breakTime;
  if (self.soundType) { [self.soundType stop]; self.soundType = nil; }
  [self setupSoundWithType:SoundTypeBreak];
  if (self.soundType) { self.soundType.numberOfLoops = 0; [self.soundType play]; }
  [self updateUI];

  FocusModeConfig *config = [self configForMode:self.currentFocusMode];
  if (self.calendarEnabled) {
    [self addCalendarEvent:@"Break" duration:breakTime];
  }
  [self showAlert:@"Work Session Complete! 🍅" msg:[NSString stringWithFormat:@"Time for a %ld min break", (long)(breakTime / 60)] btn1:@"Start Break" btn2:@"Skip"];
}

- (void)switchToWork {
  self.isWorkSession = YES;
  self.workDuration = self.workDuration ?: 25 * 60;
  self.totalSeconds = self.workDuration;
  self.remainingSeconds = self.workDuration;
  if (self.soundType) { [self.soundType stop]; self.soundType = nil; }
  [self setupSoundWithType:SoundTypeWork];
  if (self.soundType) { self.soundType.numberOfLoops = -1; [self.soundType play]; }
  [self updateUI];

  if (self.calendarEnabled) {
    [self addCalendarEvent:@"Work" duration:self.workDuration];
  }
  [self showAlert:@"Break Over! Let's focus! 💪" msg:[NSString stringWithFormat:@"Time to work for %ld min", (long)(self.workDuration / 60)] btn1:@"Start Work" btn2:@"More Break"];
}

- (void)showAlert:(NSString *)title msg:(NSString *)msg btn1:(NSString *)b1 btn2:(NSString *)b2 {
  NSAlert *a = [[NSAlert alloc] init];
  a.messageText = title;
  a.informativeText = msg;
  [a addButtonWithTitle:b1];
  [a addButtonWithTitle:b2];
  [a beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse r) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (self.soundType.playing) [self.soundType stop];
      if (r == NSAlertFirstButtonReturn) [self startTimer];
    });
  }];
}

- (void)updateUI {
  NSInteger m = self.remainingSeconds / 60;
  NSInteger s = self.remainingSeconds % 60;
  NSString *type = self.isWorkSession ? @"Work" : @"Break";
  self.timeLabel.stringValue = [NSString stringWithFormat:@"%@: %02ld:%02ld", type, (long)m, (long)s];
  self.progressBar.doubleValue = self.remainingSeconds;
  if (self.startButton) self.startButton.title = self.isRunning ? @"⏸  Pause" : @"▶  Start";
  [self updateStatusBar];
  [self updateMiniPlayer];
}

- (void)updateStatsDisplay {
  NSTextField *p = [self.window.contentView viewWithTag:101];
  if (p) p.stringValue = [NSString stringWithFormat:@"%ld", (long)self.todayCompletedPomodoros];
  NSTextField *t = [self.window.contentView viewWithTag:102];
  if (t) t.stringValue = [NSString stringWithFormat:@"%ld min", (long)(self.todayWorkSeconds / 60)];
}

#pragma mark - Sound (#12)
- (NSString *)soundsDirectory {
  NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
  NSString *soundsPath = [bundlePath stringByAppendingPathComponent:@"Contents/Resources/Sounds"];
  [[NSFileManager defaultManager] createDirectoryAtPath:soundsPath withIntermediateDirectories:YES attributes:nil error:nil];
  return soundsPath;
}

- (void)setupSoundWithType:(SoundType)type {
  NSString *fn = type == SoundTypeBreak ? @"alarm-clock" : @"fireplace";
  NSString *path = [[NSBundle mainBundle] pathForResource:fn ofType:@"mp3"];
  if (!path) {
    path = [[self soundsDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp3", fn]];
  }
  if (!path) return;
  NSError *e = nil;
  self.soundType = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&e];
  if (e) { NSLog(@"Sound error: %@", e); return; }
  self.soundType.numberOfLoops = -1;
  [self.soundType prepareToPlay];
}

- (NSString *)soundPathForFile:(NSString *)filename {
  NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:@"mp3"];
  if (!path) {
    path = [[self soundsDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp3", filename]];
  }
  return path;
}

- (void)toggleSound:(NSButton *)sender {
  NSInteger index = sender.tag;
  if (index < (NSInteger)self.soundLayers.count) {
    SoundLayer *layer = self.soundLayers[index];
    layer.isPlaying = !layer.isPlaying;

    if (layer.isPlaying) {
      NSString *path = [self soundPathForFile:layer.filename];
      if (path) {
        NSError *e = nil;
        layer.player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&e];
        layer.player.numberOfLoops = -1;
        layer.player.volume = layer.volume;
        [layer.player play];
      }
    } else {
      [layer.player stop];
      layer.player = nil;
    }
  }
}

- (void)toggleSoundByName:(NSMenuItem *)sender {
  NSString *name = sender.representedObject;
  for (SoundLayer *layer in self.soundLayers) {
    if ([layer.name isEqualToString:name]) {
      layer.isPlaying = !layer.isPlaying;
      if (layer.isPlaying) {
        NSString *path = [self soundPathForFile:layer.filename];
        if (path) {
          NSError *e = nil;
          layer.player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&e];
          layer.player.numberOfLoops = -1;
          layer.player.volume = layer.volume;
          [layer.player play];
        }
      } else {
        [layer.player stop];
      }
      break;
    }
  }
}

- (void)openMusicMixer {
  if (!self.musicWindow) {
    self.musicWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 280)
                                                styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                                  backing:NSBackingStoreBuffered defer:NO];
    self.musicWindow.title = @"🎵 Focus Sound Mixer";
    [self.musicWindow center];

    NSBox *mainBox = [[NSBox alloc] initWithFrame:NSMakeRect(10, 10, 280, 260)];
    mainBox.boxType = NSBoxCustom;
    mainBox.cornerRadius = 12;
    mainBox.fillColor = [[NSColor windowBackgroundColor] colorWithAlphaComponent:0.9];
    mainBox.borderWidth = 0;
    [self.musicWindow.contentView addSubview:mainBox];

    NSInteger y = 220;
    for (SoundLayer *layer in self.soundLayers) {
      NSTextField *label = [NSTextField labelWithString:layer.name];
      label.frame = NSMakeRect(15, y, 100, 20);
      [mainBox.contentView addSubview:label];

      NSSlider *slider = [[NSSlider alloc] initWithFrame:NSMakeRect(120, y, 100, 20)];
      slider.minValue = 0;
      slider.maxValue = 1;
      slider.doubleValue = layer.volume;
      slider.tag = [self.soundLayers indexOfObject:layer];
      [slider setTarget:self];
      [slider setAction:@selector(volumeChanged:)];
      [mainBox.contentView addSubview:slider];

      NSButton *toggle = [NSButton checkboxWithTitle:@"" target:self action:@selector(toggleSoundLayer:)];
      toggle.state = layer.isPlaying ? NSControlStateValueOn : NSControlStateValueOff;
      toggle.tag = [self.soundLayers indexOfObject:layer];
      toggle.frame = NSMakeRect(230, y, 20, 20);
      [mainBox.contentView addSubview:toggle];

      y -= 35;
    }

    NSButton *stopAll = [NSButton buttonWithTitle:@"Stop All" target:self action:@selector(stopAllSounds)];
    stopAll.bezelStyle = NSBezelStyleRounded;
    stopAll.frame = NSMakeRect(90, 15, 100, 28);
    [mainBox.contentView addSubview:stopAll];
  }
  [self.musicWindow makeKeyAndOrderFront:nil];
}

- (void)volumeChanged:(NSSlider *)sender {
  NSInteger index = sender.tag;
  if (index < (NSInteger)self.soundLayers.count) {
    self.soundLayers[index].volume = sender.doubleValue;
    self.soundLayers[index].player.volume = sender.doubleValue;
  }
}

- (void)toggleSoundLayer:(NSButton *)sender {
  NSInteger index = sender.tag;
  if (index < (NSInteger)self.soundLayers.count) {
    SoundLayer *layer = self.soundLayers[index];
    layer.isPlaying = sender.state == NSControlStateValueOn;

    if (layer.isPlaying) {
      NSString *path = [self soundPathForFile:layer.filename];
      if (path) {
        NSError *e = nil;
        layer.player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&e];
        layer.player.numberOfLoops = -1;
        layer.player.volume = layer.volume;
        [layer.player play];
      }
    } else {
      [layer.player stop];
    }
  }
}

- (void)stopAllSounds {
  for (SoundLayer *layer in self.soundLayers) {
    layer.isPlaying = NO;
    if (layer.player) {
      [layer.player stop];
      layer.player = nil;
    }
  }
  if (self.soundType) {
    [self.soundType stop];
    self.soundType = nil;
  }
}

#pragma mark - Analytics (#17)
- (void)openAnalytics {
  if (!self.analyticsWindow) {
    self.analyticsWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 450)
                                                    styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable)
                                                      backing:NSBackingStoreBuffered defer:NO];
    self.analyticsWindow.title = @"📊 Analytics Dashboard";
    [self.analyticsWindow center];

    NSBox *container = [[NSBox alloc] initWithFrame:NSMakeRect(10, 10, 480, 430)];
    container.boxType = NSBoxCustom;
    container.cornerRadius = 12;
    container.fillColor = [[NSColor windowBackgroundColor] colorWithAlphaComponent:0.9];
    container.borderWidth = 0;
    [self.analyticsWindow.contentView addSubview:container];

    NSTextField *title = [NSTextField labelWithString:@"Weekly Overview"];
    title.font = [NSFont boldSystemFontOfSize:16];
    title.frame = NSMakeRect(20, 395, 200, 24);
    [container.contentView addSubview:title];

    NSDictionary *weekly = [self getWeeklyStats];

    NSInteger chartY = 280;
    NSInteger barWidth = 55;
    NSInteger chartX = 30;

    for (NSString *day in @[@"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat", @"Sun"]) {
      NSInteger pomos = [weekly[day][@"pomodoros"] integerValue];
      CGFloat height = MIN(pomos * 15, 100);

      NSBox *bar = [[NSBox alloc] initWithFrame:NSMakeRect(chartX, chartY - height, barWidth, height)];
      bar.boxType = NSBoxCustom;
      bar.cornerRadius = 4;
      bar.fillColor = pomos > 0 ? [NSColor systemBlueColor] : [NSColor separatorColor];
      bar.borderWidth = 0;
      [container.contentView addSubview:bar];

      NSTextField *dayLabel = [NSTextField labelWithString:day];
      dayLabel.font = [NSFont systemFontOfSize:10];
      dayLabel.alignment = NSTextAlignmentCenter;
      dayLabel.frame = NSMakeRect(chartX, chartY - height - 15, barWidth, 12);
      [container.contentView addSubview:dayLabel];

      NSTextField *countLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"%ld", (long)pomos]];
      countLabel.font = [NSFont systemFontOfSize:10 weight:NSFontWeightBold];
      countLabel.alignment = NSTextAlignmentCenter;
      countLabel.frame = NSMakeRect(chartX, chartY - height + 4, barWidth, 12);
      [container.contentView addSubview:countLabel];

      chartX += barWidth + 10;
    }

    NSBox *statsBox = [[NSBox alloc] initWithFrame:NSMakeRect(20, 140, 440, 120)];
    statsBox.boxType = NSBoxCustom;
    statsBox.cornerRadius = 8;
    statsBox.fillColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.5];
    statsBox.borderWidth = 0;
    [container.contentView addSubview:statsBox];

    NSTextField *totalLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"Total Pomodoros: %ld", (long)self.totalPomodorosAllTime]];
    totalLabel.font = [NSFont systemFontOfSize:14];
    totalLabel.frame = NSMakeRect(20, 85, 200, 20);
    [statsBox.contentView addSubview:totalLabel];

    NSTextField *streakLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"Current Streak: %ld days", (long)self.currentStreak]];
    streakLabel.font = [NSFont systemFontOfSize:14];
    streakLabel.frame = NSMakeRect(20, 60, 200, 20);
    [statsBox.contentView addSubview:streakLabel];

    NSTextField *longestLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"Longest Streak: %ld days", (long)self.longestStreak]];
    longestLabel.font = [NSFont systemFontOfSize:14];
    longestLabel.frame = NSMakeRect(20, 35, 200, 20);
    [statsBox.contentView addSubview:longestLabel];

    NSTextField *levelLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"Level: %ld (%ld XP)", (long)self.userLevel, (long)self.xpPoints]];
    levelLabel.font = [NSFont systemFontOfSize:14];
    levelLabel.frame = NSMakeRect(220, 85, 200, 20);
    [statsBox.contentView addSubview:levelLabel];

    NSProgressIndicator *levelProgress = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(220, 50, 200, 16)];
    levelProgress.minValue = 0;
    levelProgress.maxValue = (self.userLevel + 1) * (self.userLevel + 1) * 100;
    levelProgress.doubleValue = self.xpPoints;
    [statsBox.contentView addSubview:levelProgress];

    NSTextField *sessionsLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"Sessions Today: %ld", (long)self.todayCompletedPomodoros]];
    sessionsLabel.font = [NSFont systemFontOfSize:14];
    sessionsLabel.frame = NSMakeRect(220, 35, 200, 20);
    [statsBox.contentView addSubview:sessionsLabel];

    NSTextField *calLabel = [NSTextField labelWithString:@"Heatmap (Last 30 days)"];
    calLabel.font = [NSFont boldSystemFontOfSize:14];
    calLabel.frame = NSMakeRect(20, 115, 200, 18);
    [container.contentView addSubview:calLabel];

    NSCalendar *cal = [NSCalendar currentCalendar];
    NSInteger calX = 20;
    NSInteger calY = 20;
    for (NSInteger i = 29; i >= 0; i--) {
      NSDate *day = [cal dateByAddingUnit:NSCalendarUnitDay value:-i toDate:[NSDate date] options:0];
      NSInteger value = [self getHeatmapValueForDay:day];

      NSColor *color;
      if (value == 0) color = [NSColor separatorColor];
      else if (value == 1) color = [NSColor systemGreenColor];
      else if (value == 2) color = [NSColor systemTealColor];
      else if (value == 3) color = [NSColor systemBlueColor];
      else color = [NSColor systemPurpleColor];

      NSBox *dot = [[NSBox alloc] initWithFrame:NSMakeRect(calX, calY, 12, 12)];
      dot.boxType = NSBoxCustom;
      dot.cornerRadius = 2;
      dot.fillColor = color;
      dot.borderWidth = 0;
      [container.contentView addSubview:dot];

      calX += 15;
      if (calX > 480) { calX = 20; calY += 15; }
    }
  }

  [self.analyticsWindow makeKeyAndOrderFront:nil];
}

#pragma mark - Achievements (#11)
- (void)openAchievements {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = @"🏆 Achievements";

  NSMutableString *body = [NSMutableString string];
  for (AchievementData *a in self.achievements) {
    NSString *status = [self.unlockedAchievements containsObject:@(a.type)] ? @"✅" : @"🔒";
    [body appendFormat:@"%@ %@ - %@ (+%ld XP)\n", status, a.title, a.achievedDescription, (long)a.xpReward];
  }
  [body appendFormat:@"\n⭐ Level: %ld | Total XP: %ld", (long)self.userLevel, (long)self.xpPoints];

  alert.informativeText = body;
  [alert addButtonWithTitle:@"Close"];
  [alert runModal];
}

#pragma mark - Calendar
- (void)toggleCalendarSync {
  if (self.calendarEnabled) {
    self.calendarEnabled = NO;
    NSLog(@"Calendar sync disabled");
  } else {
    [self requestCalendarAccess];
  }
}

#pragma mark - Notification
- (void)sendNotification {
  UNMutableNotificationContent *c = [[UNMutableNotificationContent alloc] init];
  c.title = self.isWorkSession ? @"Break Time! 🎉" : @"Focus Time! 💪";
  c.body = self.isWorkSession ? @"Great job! Take a break." : @"Break's over. Let's focus!";
  c.sound = [UNNotificationSound defaultSound];
  UNNotificationRequest *req = [UNNotificationRequest requestWithIdentifier:@"pomodoro" content:c trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO]];
  [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:req withCompletionHandler:nil];
}

#pragma mark - Settings
- (void)openSettings {
  if (!self.window) return;
  if (!self.settingsWindow) {
    self.settingsWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 320, 350) styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable) backing:NSBackingStoreBuffered defer:NO];
    self.settingsWindow.title = @"⚙️ Settings";
    [self.settingsWindow center];

    NSBox *box = [[NSBox alloc] initWithFrame:NSMakeRect(10, 10, 300, 330)];
    box.boxType = NSBoxCustom;
    box.cornerRadius = 12;
    box.fillColor = [[NSColor windowBackgroundColor] colorWithAlphaComponent:0.95];
    box.borderWidth = 0;
    [self.settingsWindow.contentView addSubview:box];

    NSTextField *modeLabel = [NSTextField labelWithString:@"Focus Mode"];
    modeLabel.font = [NSFont boldSystemFontOfSize:13];
    modeLabel.frame = NSMakeRect(20, 290, 100, 20);
    [box.contentView addSubview:modeLabel];

    NSPopUpButton *modeSelector = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(20, 255, 260, 28)];
    [modeSelector addItemWithTitle:@"Classic Pomodoro (25/5)"];
    [modeSelector addItemWithTitle:@"Deep Work (90/20)"];
    [modeSelector addItemWithTitle:@"Timeboxing (50/10)"];
    [modeSelector addItemWithTitle:@"Spicy Mode"];
    [modeSelector addItemWithTitle:@"Marathon (60/10)"];
    [modeSelector selectItemAtIndex:(NSInteger)self.currentFocusMode];
    [modeSelector setTarget:self];
    [modeSelector setAction:@selector(modeChanged:)];
    [box.contentView addSubview:modeSelector];

    NSTextField *calLabel = [NSTextField labelWithString:@"Calendar Integration"];
    calLabel.font = [NSFont boldSystemFontOfSize:13];
    calLabel.frame = NSMakeRect(20, 210, 150, 20);
    [box.contentView addSubview:calLabel];

    NSButton *calToggle = [NSButton checkboxWithTitle:@"Sync sessions to Calendar" target:self action:@selector(toggleCalendarSync)];
    calToggle.state = (self.calendarEnabled ? YES : NO) ? NSControlStateValueOn : NSControlStateValueOff;
    calToggle.frame = NSMakeRect(20, 180, 250, 20);
    [box.contentView addSubview:calToggle];

    NSTextField *dndLabel = [NSTextField labelWithString:@"Do Not Disturb"];
    dndLabel.font = [NSFont boldSystemFontOfSize:13];
    dndLabel.frame = NSMakeRect(20, 140, 150, 20);
    [box.contentView addSubview:dndLabel];

    NSButton *dndToggle = [NSButton checkboxWithTitle:@"Auto-enable DND during focus" target:self action:@selector(toggleDND:)];
    dndToggle.frame = NSMakeRect(20, 110, 250, 20);
    [box.contentView addSubview:dndToggle];

    NSButton *closeBtn = [NSButton buttonWithTitle:@"Close" target:self action:@selector(cancelSettings)];
    closeBtn.bezelStyle = NSBezelStyleRounded;
    closeBtn.frame = NSMakeRect(110, 20, 80, 28);
    [box.contentView addSubview:closeBtn];
  }
  [self.settingsWindow center];
  if (self.window) {
    [self.window beginSheet:self.settingsWindow completionHandler:nil];
  } else {
    [self.settingsWindow makeKeyAndOrderFront:nil];
  }
}

- (void)modeChanged:(NSPopUpButton *)sender {
  [self setFocusMode:sender.indexOfSelectedItem];
}

- (void)toggleDND:(NSButton *)sender {
  if (sender.state == NSControlStateValueOn) {
    [self enableDND];
  } else {
    [self disableDND];
  }
}

- (void)cancelSettings {
  [self.window endSheet:self.settingsWindow];
}

#pragma mark - Sound Downloads
- (void)openSoundDownloader {
  if (!self.soundsWindow) {
    self.soundsWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 450, 380)
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                                backing:NSBackingStoreBuffered defer:NO];
    self.soundsWindow.title = @"🎵 Download Focus Sounds";
    [self.soundsWindow center];

    NSVisualEffectView *bg = [[NSVisualEffectView alloc] initWithFrame:self.soundsWindow.contentView.bounds];
    bg.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    bg.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    bg.material = NSVisualEffectMaterialHUDWindow;
    bg.state = NSVisualEffectStateActive;
    [self.soundsWindow.contentView addSubview:bg];

    NSBox *contentBox = [[NSBox alloc] initWithFrame:NSMakeRect(10, 10, 430, 360)];
    contentBox.boxType = NSBoxCustom;
    contentBox.cornerRadius = 16;
    contentBox.fillColor = [[NSColor windowBackgroundColor] colorWithAlphaComponent:0.9];
    contentBox.borderWidth = 0;
    [bg addSubview:contentBox];

    NSTextField *title = [NSTextField labelWithString:@"Download Free Focus Sounds"];
    title.font = [NSFont systemFontOfSize:16 weight:NSFontWeightBold];
    title.frame = NSMakeRect(15, 315, 400, 24);
    [contentBox.contentView addSubview:title];

    NSTextField *desc = [NSTextField labelWithString:@"Click download to get sounds from Pixabay (royalty-free)"];
    desc.font = [NSFont systemFontOfSize:11];
    desc.textColor = [NSColor secondaryLabelColor];
    desc.frame = NSMakeRect(15, 295, 400, 16);
    [contentBox.contentView addSubview:desc];

    NSArray *sounds = @[
      @{@"name": @"🌧️ Rain", @"file": @"rain", @"url": @"https://pixabay.com/music/search/?q=rain+sounds&duration=0-600"},
      @{@"name": @"🌲 Forest", @"file": @"forest", @"url": @"https://pixabay.com/music/search/?q=forest+sounds+nature"},
      @{@"name": @"☕ Cafe", @"file": @"cafe", @"url": @"https://pixabay.com/music/search/?q=cafe+ambience"},
      @{@"name": @"🌊 Ocean", @"file": @"ocean", @"url": @"https://pixabay.com/music/search/?q=ocean+waves"},
      @{@"name": @"🔥 Fireplace", @"file": @"fireplace", @"url": @"https://pixabay.com/music/search/?q=fireplace+crackling"},
      @{@"name": @"📻 White Noise", @"file": @"whitenoise", @"url": @"https://pixabay.com/music/search/?q=white+noise"}
    ];

    NSInteger y = 260;
    for (NSDictionary *sound in sounds) {
      NSString *filename = sound[@"file"];
      BOOL downloaded = [[NSFileManager defaultManager] fileExistsAtPath:[[self soundsDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp3", filename]]];

      NSBox *rowBox = [[NSBox alloc] initWithFrame:NSMakeRect(15, y, 400, 38)];
      rowBox.boxType = NSBoxCustom;
      rowBox.cornerRadius = 10;
      rowBox.fillColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.5];
      rowBox.borderWidth = 0;
      [contentBox.contentView addSubview:rowBox];

      NSTextField *nameLabel = [NSTextField labelWithString:sound[@"name"]];
      nameLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
      nameLabel.frame = NSMakeRect(12, 10, 180, 20);
      [rowBox.contentView addSubview:nameLabel];

      if (downloaded) {
        NSTextField *statusLabel = [NSTextField labelWithString:@"✅ Downloaded"];
        statusLabel.font = [NSFont systemFontOfSize:11];
        statusLabel.textColor = [NSColor systemGreenColor];
        statusLabel.frame = NSMakeRect(200, 12, 100, 16);
        [rowBox.contentView addSubview:statusLabel];

        NSButton *playBtn = [NSButton buttonWithTitle:@"▶ Play" target:self action:@selector(playSoundFromDownloader:)];
        playBtn.bezelStyle = NSBezelStyleRounded;
        playBtn.frame = NSMakeRect(310, 6, 80, 26);
        playBtn.representedObject = filename;
        [rowBox.contentView addSubview:playBtn];
      } else {
        NSButton *downloadBtn = [NSButton buttonWithTitle:@"⬇ Download" target:self action:@selector(openPixabaySearch:)];
        downloadBtn.bezelStyle = NSBezelStyleRounded;
        downloadBtn.frame = NSMakeRect(200, 6, 100, 26);
        downloadBtn.representedObject = sound[@"url"];
        [rowBox.contentView addSubview:downloadBtn];
      }

      y -= 48;
    }

    NSTextField *footer = [NSTextField labelWithString:@"Tip: Download 30-60 second loops for best experience"];
    footer.font = [NSFont systemFontOfSize:10];
    footer.textColor = [NSColor tertiaryLabelColor];
    footer.frame = NSMakeRect(15, 5, 400, 14);
    [contentBox.contentView addSubview:footer];
  }

  [self.soundsWindow makeKeyAndOrderFront:nil];
}

- (void)openPixabaySearch:(NSButton *)sender {
  NSString *url = sender.representedObject;
  if (url) {
    NSURL *searchURL = [NSURL URLWithString:url];
    [[NSWorkspace sharedWorkspace] openURL:searchURL];
  }
}

- (void)playSoundFromDownloader:(NSButton *)sender {
  NSString *filename = sender.representedObject;
  if (filename) {
    NSString *path = [self soundPathForFile:filename];
    if (path) {
      NSError *e = nil;
      AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&e];
      if (!e) {
        player.numberOfLoops = -1;
        [player play];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          [player stop];
        });
      }
    }
  }
}

#pragma mark - Tasks
- (void)openTasksWindow {
  if (!self.taskWindow) {
    self.taskWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 450)
                                                styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable)
                                                  backing:NSBackingStoreBuffered defer:NO];
    self.taskWindow.title = @"📋 Manage Tasks";
    self.taskWindow.minSize = NSMakeSize(450, 400);
    [self.taskWindow center];

    NSVisualEffectView *bg = [[NSVisualEffectView alloc] initWithFrame:self.taskWindow.contentView.bounds];
    bg.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    bg.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    bg.material = NSVisualEffectMaterialHUDWindow;
    bg.state = NSVisualEffectStateActive;
    [self.taskWindow.contentView addSubview:bg];

    NSBox *contentBox = [[NSBox alloc] initWithFrame:NSMakeRect(10, 10, 480, 430)];
    contentBox.boxType = NSBoxCustom;
    contentBox.cornerRadius = 12;
    contentBox.fillColor = [[NSColor windowBackgroundColor] colorWithAlphaComponent:0.9];
    contentBox.borderWidth = 0;
    [bg addSubview:contentBox];

    NSBox *headerBox = [[NSBox alloc] initWithFrame:NSMakeRect(0, 385, 480, 50)];
    headerBox.boxType = NSBoxCustom;
    headerBox.cornerRadius = 0;
    headerBox.fillColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.5];
    headerBox.borderWidth = 0;
    [contentBox.contentView addSubview:headerBox];

    NSTextField *title = [NSTextField labelWithString:@"My Tasks"];
    title.font = [NSFont systemFontOfSize:18 weight:NSFontWeightBold];
    title.frame = NSMakeRect(20, 15, 150, 24);
    [headerBox.contentView addSubview:title];

    self.taskCountLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"%ld tasks", (long)self.tasks.count]];
    self.taskCountLabel.font = [NSFont systemFontOfSize:13];
    self.taskCountLabel.textColor = [NSColor secondaryLabelColor];
    self.taskCountLabel.frame = NSMakeRect(170, 18, 100, 20);
    [headerBox.contentView addSubview:self.taskCountLabel];

    NSButton *newTaskBtn = [NSButton buttonWithTitle:@"New Task" target:self action:@selector(addTaskFromModal)];
    newTaskBtn.bezelStyle = NSBezelStyleAccessoryBarAction;
    newTaskBtn.frame = NSMakeRect(350, 13, 120, 24);
    if (@available(macOS 11.0, *)) {
      [newTaskBtn setImage:[NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:@"Add"]];
      newTaskBtn.imagePosition = NSImageLeading;
    }
    [headerBox.contentView addSubview:newTaskBtn];

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 60, 460, 310)];
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSBezelBorder;
    scroll.drawsBackground = YES;
    scroll.backgroundColor = [[NSColor windowBackgroundColor] colorWithAlphaComponent:0.5];

    self.taskTableView = [[NSTableView alloc] init];
    self.taskTableView.delegate = self;
    self.taskTableView.dataSource = self;
    self.taskTableView.usesAlternatingRowBackgroundColors = YES;
    self.taskTableView.style = NSTableViewStyleSourceList;
    self.taskTableView.rowHeight = 36;
    self.taskTableView.headerView = nil;

    NSTableColumn *checkCol = [[NSTableColumn alloc] initWithIdentifier:@"done"];
    checkCol.title = @"";
    checkCol.width = 35;
    [self.taskTableView addTableColumn:checkCol];

    NSTableColumn *titleCol = [[NSTableColumn alloc] initWithIdentifier:@"title"];
    titleCol.title = @"Task";
    titleCol.width = 300;
    [self.taskTableView addTableColumn:titleCol];

    NSTableColumn *pomoCol = [[NSTableColumn alloc] initWithIdentifier:@"pomodoros"];
    pomoCol.title = @"Pomodoros";
    pomoCol.width = 90;
    [self.taskTableView addTableColumn:pomoCol];

    scroll.documentView = self.taskTableView;
    [contentBox.contentView addSubview:scroll];

    NSStackView *actionStack = [[NSStackView alloc] initWithFrame:NSMakeRect(10, 10, 460, 40)];
    actionStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    actionStack.spacing = 8;
    actionStack.distribution = NSStackViewDistributionFillEqually;

    NSButton *checkAllBtn = [NSButton buttonWithTitle:@"✓ Check All" target:self action:@selector(checkAllCompleted)];
    checkAllBtn.bezelStyle = NSBezelStyleInline;
    checkAllBtn.font = [NSFont systemFontOfSize:11];
    [actionStack addArrangedSubview:checkAllBtn];

    NSButton *uncheckAllBtn = [NSButton buttonWithTitle:@"✗ Uncheck All" target:self action:@selector(uncheckAll)];
    uncheckAllBtn.bezelStyle = NSBezelStyleInline;
    uncheckAllBtn.font = [NSFont systemFontOfSize:11];
    [actionStack addArrangedSubview:uncheckAllBtn];

    NSButton *deleteSelectedBtn = [NSButton buttonWithTitle:@"🗑 Delete Selected" target:self action:@selector(deleteSelectedTaskModal)];
    deleteSelectedBtn.bezelStyle = NSBezelStyleInline;
    deleteSelectedBtn.font = [NSFont systemFontOfSize:11];
    [actionStack addArrangedSubview:deleteSelectedBtn];

    NSButton *deleteDoneBtn = [NSButton buttonWithTitle:@"🧹 Remove Completed" target:self action:@selector(deleteCompletedTasks)];
    deleteDoneBtn.bezelStyle = NSBezelStyleInline;
    deleteDoneBtn.font = [NSFont systemFontOfSize:11];
    [actionStack addArrangedSubview:deleteDoneBtn];

    NSButton *deleteAllBtn = [NSButton buttonWithTitle:@"⚠️ Delete All" target:self action:@selector(deleteAllTasks)];
    deleteAllBtn.bezelStyle = NSBezelStyleInline;
    deleteAllBtn.font = [NSFont systemFontOfSize:11];
    [actionStack addArrangedSubview:deleteAllBtn];

    [contentBox.contentView addSubview:actionStack];
  }

  [self.taskTableView reloadData];
  [self updateTaskCount];
  [self.taskWindow makeKeyAndOrderFront:nil];
}

- (void)updateTaskCount {
  if (self.taskCountLabel) {
    self.taskCountLabel.stringValue = [NSString stringWithFormat:@"%ld tasks", (long)self.tasks.count];
  }
}

- (void)addTaskFromModal {
  NSAlert *a = [[NSAlert alloc] init];
  a.messageText = @"New Task 🍅";
  a.informativeText = @"Enter task name:";
  NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 24)];
  [a setAccessoryView:tf];
  [a addButtonWithTitle:@"Add"];
  [a addButtonWithTitle:@"Cancel"];
  if ([a runModal] == NSAlertFirstButtonReturn && tf.stringValue.length > 0) {
    PomodoroTask *t = [[PomodoroTask alloc] init];
    t.taskId = [[NSUUID UUID] UUIDString];
    t.title = tf.stringValue;
    t.isCompleted = NO;
    t.pomodorosSpent = 0;
    [self.tasks addObject:t];
    [self saveData];
    [self.taskTableView reloadData];
    [self updateTaskCount];
  }
}

- (void)deleteSelectedTaskModal {
  NSInteger selectedRow = self.taskTableView.selectedRow;
  if (selectedRow >= 0 && selectedRow < (NSInteger)self.tasks.count) {
    [self.tasks removeObjectAtIndex:selectedRow];
    [self saveData];
    [self.taskTableView reloadData];
    [self updateTaskCount];
  } else {
    NSAlert *noSelection = [[NSAlert alloc] init];
    noSelection.messageText = @"No Task Selected";
    noSelection.informativeText = @"Please select a task to delete.";
    [noSelection addButtonWithTitle:@"OK"];
    [noSelection runModal];
  }
}

- (void)addTask {
  NSAlert *a = [[NSAlert alloc] init];
  a.messageText = @"New Task 🍅";
  a.informativeText = @"Enter task name:";
  NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 24)];
  [a setAccessoryView:tf];
  [a addButtonWithTitle:@"Add"];
  [a addButtonWithTitle:@"Cancel"];
  if ([a runModal] == NSAlertFirstButtonReturn && tf.stringValue.length > 0) {
    PomodoroTask *t = [[PomodoroTask alloc] init];
    t.taskId = [[NSUUID UUID] UUIDString];
    t.title = tf.stringValue;
    t.isCompleted = NO;
    t.pomodorosSpent = 0;
    [self.tasks addObject:t];
    [self saveData];
    [self.taskTableView reloadData];
    [self updateMainTaskCount];
  }
}

- (void)deleteTaskFromMain {
  NSInteger selectedRow = self.taskTableView.selectedRow;
  if (selectedRow >= 0 && selectedRow < (NSInteger)self.tasks.count) {
    [self.tasks removeObjectAtIndex:selectedRow];
    [self saveData];
    [self.taskTableView reloadData];
    [self updateMainTaskCount];
  } else {
    NSAlert *noSelection = [[NSAlert alloc] init];
    noSelection.messageText = @"No Task Selected";
    noSelection.informativeText = @"Please select a task to delete.";
    [noSelection addButtonWithTitle:@"OK"];
    [noSelection runModal];
  }
}

- (void)updateMainTaskCount {
  if (self.taskCountLabel) {
    self.taskCountLabel.stringValue = [NSString stringWithFormat:@"%ld tasks", (long)self.tasks.count];
  }
}

- (void)checkAllCompleted {
  for (PomodoroTask *task in self.tasks) {
    task.isCompleted = YES;
  }
  [self saveData];
  [self.taskTableView reloadData];
  [self updateMainTaskCount];
}

- (void)uncheckAll {
  for (PomodoroTask *task in self.tasks) {
    task.isCompleted = NO;
  }
  [self saveData];
  [self.taskTableView reloadData];
  [self updateMainTaskCount];
}

- (void)deleteCompletedTasks {
  NSMutableArray *toRemove = [NSMutableArray array];
  for (PomodoroTask *task in self.tasks) {
    if (task.isCompleted) {
      [toRemove addObject:task];
    }
  }
  if (toRemove.count == 0) {
    NSAlert *noCompleted = [[NSAlert alloc] init];
    noCompleted.messageText = @"No Completed Tasks";
    noCompleted.informativeText = @"There are no completed tasks to delete.";
    [noCompleted addButtonWithTitle:@"OK"];
    [noCompleted runModal];
    return;
  }
  [self.tasks removeObjectsInArray:toRemove];
  [self saveData];
  [self.taskTableView reloadData];
  [self updateMainTaskCount];
}

- (void)deleteAllTasks {
  if (self.tasks.count == 0) {
    NSAlert *noTasks = [[NSAlert alloc] init];
    noTasks.messageText = @"No Tasks";
    noTasks.informativeText = @"There are no tasks to delete.";
    [noTasks addButtonWithTitle:@"OK"];
    [noTasks runModal];
    return;
  }
  NSAlert *confirm = [[NSAlert alloc] init];
  confirm.messageText = @"Delete All Tasks?";
  confirm.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete all %ld tasks?", (long)self.tasks.count];
  [confirm addButtonWithTitle:@"Delete All"];
  [confirm addButtonWithTitle:@"Cancel"];
  if ([confirm runModal] == NSAlertFirstButtonReturn) {
    [self.tasks removeAllObjects];
    [self saveData];
    [self.taskTableView reloadData];
    [self updateMainTaskCount];
  }
}

- (void)removeCompletedFromTasks {
  NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
  for (NSUInteger i = 0; i < self.tasks.count; i++) {
    if (self.tasks[i].isCompleted) {
      [indexSet addIndex:i];
    }
  }
  if (indexSet.count > 0) {
    [self.tasks removeObjectsAtIndexes:indexSet];
  }
}

#pragma mark - TableView
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv { return self.tasks.count; }

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tc row:(NSInteger)r {
  if (r >= (NSInteger)self.tasks.count) return @"";
  PomodoroTask *t = self.tasks[r];
  if ([tc.identifier isEqualToString:@"done"]) return @(t.isCompleted);
  if ([tc.identifier isEqualToString:@"title"]) return t.title;
  if ([tc.identifier isEqualToString:@"pomodoros"]) return [NSString stringWithFormat:@"%ld 🍅", (long)t.pomodorosSpent];
  return @"";
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)v forTableColumn:(NSTableColumn *)tc row:(NSInteger)r {
  if (r >= 0 && r < (NSInteger)self.tasks.count && [tc.identifier isEqualToString:@"done"]) {
    self.tasks[r].isCompleted = !self.tasks[r].isCompleted;
    if (self.tasks[r].isCompleted) self.tasks[r].pomodorosSpent++;
    [self saveData];
    [tv reloadData];
    [self updateMainTaskCount];
  }
}

#pragma mark - Data Helpers
- (void)updateTodayStats {
  NSCalendar *cal = [NSCalendar currentCalendar];
  NSDate *today = [cal startOfDayForDate:[NSDate date]];
  self.todayCompletedPomodoros = 0;
  self.todayWorkSeconds = 0;
  for (PomodoroRecord *rec in self.records) {
    if ([cal isDate:rec.date inSameDayAsDate:today]) {
      self.todayCompletedPomodoros += rec.completedPomodoros;
      self.todayWorkSeconds += rec.workSeconds;
    }
  }
}

- (void)recordPomodoro:(NSInteger)seconds {
  NSCalendar *cal = [NSCalendar currentCalendar];
  NSDate *today = [cal startOfDayForDate:[NSDate date]];
  PomodoroRecord *todayRec = nil;
  for (PomodoroRecord *rec in self.records) {
    if ([cal isDate:rec.date inSameDayAsDate:today]) { todayRec = rec; break; }
  }
  if (!todayRec) {
    todayRec = [[PomodoroRecord alloc] init];
    todayRec.date = today;
    todayRec.workSeconds = 0;
    todayRec.completedPomodoros = 0;
    [self.records addObject:todayRec];
  }
  todayRec.workSeconds += seconds;
  todayRec.completedPomodoros += 1;
  self.totalPomodorosAllTime++;
  self.todayCompletedPomodoros = todayRec.completedPomodoros;
  self.todayWorkSeconds = todayRec.workSeconds;
  [self saveData];
  [self updateStatsDisplay];
}

#pragma mark - Helper
- (NSString *)formatTime:(NSInteger)s {
  return [NSString stringWithFormat:@"%02ld:%02ld", (long)(s / 60), (long)(s % 60)];
}

- (void)applicationWillTerminate:(NSNotification *)n {
  [self saveData];
  [self stopAllSounds];
}
@end

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    AppDelegate *del = [[AppDelegate alloc] init];
    [app setDelegate:del];
    [app run];
    return 0;
  }
}
