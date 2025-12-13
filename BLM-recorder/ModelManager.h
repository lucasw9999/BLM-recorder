
#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <CoreML/CoreML.h>

@interface ModelManager : NSObject

// Singleton instance
+ (instancetype)shared;

// Load a CoreML model by name (name of the model file without extension)
- (BOOL)loadModelWithName:(NSString *)modelName error:(NSError **)error;

// Get a reference to a VNCoreMLModel by model name
- (VNCoreMLModel *)modelWithName:(NSString *)name;

@end
