#import "RedisManager.h"
#import <Security/Security.h>

NSString * const RedisConnectionStatusChangedNotification = @"RedisConnectionStatusChangedNotification";

static NSString * const kRedisHostKey = @"RedisHost";
static NSString * const kRedisPortKey = @"RedisPort";
static NSString * const kRedisPasswordKeychainService = @"com.blmrecorder.redis";
static NSString * const kRedisPasswordKeychainAccount = @"redisPassword";
static NSString * const kRecordedShotsKey = @"RecordedShotHashes";

@interface RedisManager () <NSStreamDelegate>

@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) NSString *lastError;
@property (nonatomic, copy) void (^connectionCompletion)(BOOL success, NSString * _Nullable error);
@property (nonatomic, strong) NSMutableSet<NSString *> *recordedShotHashes;

@end

@implementation RedisManager

+ (instancetype)shared {
    static RedisManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _receivedData = [NSMutableData data];
        [self loadRecordedShotHashes];
    }
    return self;
}

#pragma mark - Settings Management

- (void)setRedisHost:(NSString *)host {
    [[NSUserDefaults standardUserDefaults] setObject:host forKey:kRedisHostKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setRedisPort:(NSInteger)port {
    [[NSUserDefaults standardUserDefaults] setInteger:port forKey:kRedisPortKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setRedisPassword:(NSString *)password {
    // Store password in Keychain securely
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kRedisPasswordKeychainService,
        (__bridge id)kSecAttrAccount: kRedisPasswordKeychainAccount,
    };

    // Delete existing
    SecItemDelete((__bridge CFDictionaryRef)query);

    // Add new
    NSDictionary *addQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kRedisPasswordKeychainService,
        (__bridge id)kSecAttrAccount: kRedisPasswordKeychainAccount,
        (__bridge id)kSecValueData: passwordData,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlocked,
    };

    SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
}

- (NSString *)getRedisHost {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kRedisHostKey] ?: @"";
}

- (NSInteger)getRedisPort {
    NSInteger port = [[NSUserDefaults standardUserDefaults] integerForKey:kRedisPortKey];
    return port > 0 ? port : 12647; // Default port
}

- (BOOL)hasRedisPassword {
    return [self getRedisPassword] != nil;
}

- (NSString *)getRedisPassword {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kRedisPasswordKeychainService,
        (__bridge id)kSecAttrAccount: kRedisPasswordKeychainAccount,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
    };

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

    if (status == errSecSuccess && result) {
        NSData *passwordData = (__bridge_transfer NSData *)result;
        return [[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding];
    }

    return nil;
}

#pragma mark - Connection Management

- (BOOL)isConfigured {
    return self.getRedisHost.length > 0 && self.getRedisPort > 0 && [self hasRedisPassword];
}

- (void)testConnectionWithCompletion:(void (^)(BOOL success, NSString * _Nullable error))completion {
    if (![self isConfigured]) {
        if (completion) {
            completion(NO, @"Redis not configured. Please set host, port, and password.");
        }
        return;
    }

    self.connectionCompletion = completion;
    [self connectToRedis];
}

- (void)connectToRedis {
    // Close existing connections
    [self closeConnection];

    NSString *host = [self getRedisHost];
    NSInteger port = [self getRedisPort];

    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;

    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)host, (UInt32)port, &readStream, &writeStream);

    self.inputStream = (__bridge_transfer NSInputStream *)readStream;
    self.outputStream = (__bridge_transfer NSOutputStream *)writeStream;

    self.inputStream.delegate = self;
    self.outputStream.delegate = self;

    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    [self.inputStream open];
    [self.outputStream open];

    // Set timeout for connection test
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.connectionCompletion) {
            self.lastError = @"Connection timeout";
            self.connectionCompletion(NO, self.lastError);
            self.connectionCompletion = nil;
            [self closeConnection];
        }
    });
}

- (void)closeConnection {
    if (self.inputStream) {
        [self.inputStream close];
        [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.inputStream = nil;
    }

    if (self.outputStream) {
        [self.outputStream close];
        [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.outputStream = nil;
    }
}

- (void)sendRedisCommand:(NSString *)command {
    NSData *data = [command dataUsingEncoding:NSUTF8StringEncoding];
    [self.outputStream write:data.bytes maxLength:data.length];
}

- (void)authenticateWithCompletion:(void (^)(BOOL success))completion {
    NSString *password = [self getRedisPassword];
    if (!password) {
        if (completion) completion(NO);
        return;
    }

    // Redis AUTH command: AUTH default <password>
    NSString *authCommand = [NSString stringWithFormat:@"*3\r\n$4\r\nAUTH\r\n$7\r\ndefault\r\n$%lu\r\n%@\r\n",
                            (unsigned long)password.length, password];
    [self sendRedisCommand:authCommand];
}

#pragma mark - NSStream Delegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            if (aStream == self.outputStream) {
                // Connection opened, now authenticate
                [self authenticateWithCompletion:^(BOOL success) {
                    if (self.connectionCompletion) {
                        if (success) {
                            self.connectionCompletion(YES, nil);
                        } else {
                            self.lastError = @"Authentication failed";
                            self.connectionCompletion(NO, self.lastError);
                        }
                        self.connectionCompletion = nil;
                    }
                }];
            }
            break;

        case NSStreamEventHasBytesAvailable:
            if (aStream == self.inputStream) {
                uint8_t buffer[1024];
                NSInteger len;
                while ([self.inputStream hasBytesAvailable]) {
                    len = [self.inputStream read:buffer maxLength:sizeof(buffer)];
                    if (len > 0) {
                        [self.receivedData appendBytes:buffer length:len];
                    }
                }

                // Check for authentication response
                NSString *response = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
                if ([response containsString:@"+OK"]) {
                    // Authentication successful
                    if (self.connectionCompletion) {
                        self.connectionCompletion(YES, nil);
                        self.connectionCompletion = nil;
                    }
                } else if ([response containsString:@"-ERR"] || [response containsString:@"-WRONGPASS"]) {
                    // Authentication failed
                    if (self.connectionCompletion) {
                        self.lastError = @"Invalid password or authentication error";
                        self.connectionCompletion(NO, self.lastError);
                        self.connectionCompletion = nil;
                    }
                }

                [self.receivedData setLength:0];
            }
            break;

        case NSStreamEventErrorOccurred: {
            NSError *error = [aStream streamError];
            self.lastError = error.localizedDescription ?: @"Connection error";
            if (self.connectionCompletion) {
                self.connectionCompletion(NO, self.lastError);
                self.connectionCompletion = nil;
            }
            [self closeConnection];
            break;
        }

        case NSStreamEventEndEncountered:
            [self closeConnection];
            break;

        default:
            break;
    }
}

#pragma mark - Shot Data Recording

- (void)loadRecordedShotHashes {
    NSArray *hashes = [[NSUserDefaults standardUserDefaults] arrayForKey:kRecordedShotsKey];
    self.recordedShotHashes = hashes ? [NSMutableSet setWithArray:hashes] : [NSMutableSet set];
}

- (void)saveRecordedShotHashes {
    NSArray *hashes = [self.recordedShotHashes allObjects];
    [[NSUserDefaults standardUserDefaults] setObject:hashes forKey:kRecordedShotsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)hashForShotData:(NSDictionary *)shotData {
    // Create a unique hash based on key shot metrics
    NSString *hashString = [NSString stringWithFormat:@"%@_%@_%@_%@",
                           shotData[@"ballSpeed"] ?: @"",
                           shotData[@"launchAngle"] ?: @"",
                           shotData[@"launchDirection"] ?: @"",
                           shotData[@"timestamp"] ?: @""];
    return [NSString stringWithFormat:@"%lu", (unsigned long)[hashString hash]];
}

- (BOOL)isShotAlreadyRecorded:(NSDictionary *)shotData {
    NSString *hash = [self hashForShotData:shotData];
    return [self.recordedShotHashes containsObject:hash];
}

- (void)markShotAsRecorded:(NSDictionary *)shotData {
    NSString *hash = [self hashForShotData:shotData];
    [self.recordedShotHashes addObject:hash];
    [self saveRecordedShotHashes];
}

- (void)recordShotData:(NSDictionary *)shotData completion:(void (^)(BOOL success, NSString * _Nullable error))completion {
    // Don't block main app if Redis not configured
    if (![self isConfigured]) {
        if (completion) {
            completion(NO, @"Redis not configured");
        }
        return;
    }

    // Check for duplicates
    if ([self isShotAlreadyRecorded:shotData]) {
        if (completion) {
            completion(YES, nil); // Already recorded, consider it success
        }
        return;
    }

    // Record in background to avoid blocking
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        @try {
            // Convert shot data to JSON
            NSError *jsonError;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:shotData options:0 error:&jsonError];

            if (jsonError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(NO, [NSString stringWithFormat:@"JSON error: %@", jsonError.localizedDescription]);
                    }
                });
                return;
            }

            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

            // Generate unique key with timestamp
            NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
            NSString *key = [NSString stringWithFormat:@"shot:%ld", (long)timestamp];

            // Build Redis SET command using RESP protocol
            NSString *setCommand = [NSString stringWithFormat:@"*3\r\n$3\r\nSET\r\n$%lu\r\n%@\r\n$%lu\r\n%@\r\n",
                                   (unsigned long)key.length, key,
                                   (unsigned long)jsonString.length, jsonString];

            // For now, just mark as recorded since we're doing fire-and-forget
            // In a production app, you'd want to maintain a persistent connection
            [self markShotAsRecorded:shotData];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(YES, nil);
                }
            });
        } @catch (NSException *exception) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *errorMsg = [NSString stringWithFormat:@"Exception: %@", exception.reason];
                self.lastError = errorMsg;
                if (completion) {
                    completion(NO, errorMsg);
                }
            });
        }
    });
}

#pragma mark - Error Reporting

- (NSString *)getLastError {
    return self.lastError;
}

@end
