#import "ModelManager.h"
#import <CoreML/CoreML.h>

@interface ModelManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, VNCoreMLModel *> *modelDictionary;
@end

@implementation ModelManager

+ (instancetype)shared {
    static ModelManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        sharedInstance.modelDictionary = [NSMutableDictionary dictionary];
    });
    return sharedInstance;
}

- (BOOL)loadModelWithName:(NSString *)modelName error:(NSError **)error {
    if (self.modelDictionary[modelName]) {
        return YES; // Already loaded
    }

    // Locate the model file (.mlmodelc compiled automatically by Xcode)
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:modelName withExtension:@"mlmodelc"];
    if (!modelURL) {
        if (error) {
            *error = [NSError errorWithDomain:@"ModelManager"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Model file '%@' not found.", modelName]}];
        }
        return NO;
    }

    // Load MLModel
    NSError *coreMLError = nil;
    MLModel *coreMLModel = [MLModel modelWithContentsOfURL:modelURL error:&coreMLError];
    if (!coreMLModel) {
        if (error) {
            *error = coreMLError;
        }
        return NO;
    }

    // Convert to VNCoreMLModel
    VNCoreMLModel *vnModel = [VNCoreMLModel modelForMLModel:coreMLModel error:&coreMLError];
    if (!vnModel) {
        if (error) {
            *error = coreMLError;
        }
        return NO;
    }

    if (!self.modelDictionary) {
        self.modelDictionary = [NSMutableDictionary dictionary];
    }

    self.modelDictionary[modelName] = vnModel;

    return YES;
}

- (VNCoreMLModel *)modelWithName:(NSString *)name {
    return self.modelDictionary[name];
}

@end
