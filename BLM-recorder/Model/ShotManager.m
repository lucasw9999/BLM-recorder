#import "ShotManager.h"

@implementation ShotManager

#pragma mark - Add a New Shot

- (void)addShot:(NSDictionary *)shotDict {
    // Store it in shotList
    // Make a mutable copy so we can update it later if needed
    NSMutableDictionary *mutableShot = [shotDict mutableCopy];
    
    if (self.miniGameManager) {
        NSDictionary* miniGameData = [self.miniGameManager addShot:shotDict];
        [mutableShot addEntriesFromDictionary:miniGameData];
    }
    
    [self.shotList addObject:mutableShot];
}

#pragma mark - Update the Most Recent Shot's Club Data

- (void)updateShotClubData:(NSDictionary *)clubDict {
    if (self.shotList.count == 0) {
        return; // No shots to update
    }
    
    // Merge these keys into the *most recent* shot dictionary
    NSMutableDictionary *latestShot = self.shotList.lastObject;
    [latestShot addEntriesFromDictionary:clubDict];
}

#pragma mark - Export Shots to CSV

- (NSString *)exportShotsAsCSV {
    // 1) Collect all unique keys across all shots
    NSMutableSet<NSString *> *allKeys = [NSMutableSet set];
    for (NSDictionary *shot in self.shotList) {
        [allKeys addObjectsFromArray:shot.allKeys];
    }
    
    // Sort them alphabetically (or any other order you like)
    NSArray<NSString *> *sortedKeys = [allKeys.allObjects sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    // 2) Build the CSV header row
    NSMutableString *csvString = [NSMutableString string];
    [csvString appendString:[sortedKeys componentsJoinedByString:@","]];
    [csvString appendString:@"\n"];
    
    // 3) For each shot, build a row
    for (NSDictionary *shot in self.shotList) {
        NSMutableArray<NSString *> *rowValues = [NSMutableArray array];
        
        for (NSString *key in sortedKeys) {
            // If the shot doesn't have this key, leave blank
            id value = shot[key];
            if (value) {
                [rowValues addObject:[NSString stringWithFormat:@"%@", value]];
            } else {
                [rowValues addObject:@""]; // empty cell
            }
        }
        
        NSString *rowString = [rowValues componentsJoinedByString:@","];
        [csvString appendString:rowString];
        [csvString appendString:@"\n"];
    }
    
    return [csvString copy];
}

@end
