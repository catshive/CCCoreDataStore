//
//  CCCoreDataStore.m
//
//  Created by Cathy Shive on 7/10/12.
//
//  Copyright (c) 2012 Cathy Shive
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "CCCoreDataStore.h"

@interface NSManagedObject (CCCoreDataStore)

+ (NSString *)entityName;

@end

@implementation NSManagedObject (CCCoreDataStore)

+ (NSString *)entityName
{
    return NSStringFromClass(self);
}

@end

@interface CCCoreDataStore ()

@property (nonatomic, readwrite, strong) NSManagedObjectContext *defaultContext;

@property (nonatomic, readwrite, strong) NSManagedObjectContext *backgroundContext;

@property (nonatomic, strong) NSManagedObjectContext *parentSaveContext;

@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;

@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, strong) NSString *filePath;

@property (nonatomic, strong) NSString *storeName;

@end

@implementation CCCoreDataStore

#pragma mark - Initialize

- (instancetype)initWithStoreName:(NSString *)theName
{
    return [self initWithStoreName:theName shouldDeleteCurrentStore:NO];
}

- (instancetype)initWithStoreName:(NSString *)theName shouldDeleteCurrentStore:(BOOL)theBool
{
    if (self = [super init]) {
        self.storeName = theName;
        self.filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        self.filePath = [self.filePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite", self.storeName]];
        if (theBool) {
            [self resetStore];
        }
        [self setUpContexts];
    }
    return  self;
}

#pragma mark - Clean up

- (void)cleanupStack
{
    self.defaultContext = nil;
    self.backgroundContext = nil;
    self.parentSaveContext = nil;
    self.managedObjectModel = nil;
    self.persistentStoreCoordinator = nil;
}

#pragma mark - Reset

- (void)resetContext
{
    self.defaultContext = nil;
    self.backgroundContext = nil;
    self.parentSaveContext = nil;
    [self setUpContexts];
}

- (void)resetStore
{
    // Tear down current stack
    [self cleanupStack];
    
    // Delete the sqlite files
    NSURL *aStoreURL = [NSURL fileURLWithPath:self.filePath];
    NSError *anError = nil;
    if (aStoreURL) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:aStoreURL.path]) {
            [[NSFileManager defaultManager] removeItemAtPath:aStoreURL.path error:&anError];
        }
        if (anError) {
            NSLog(@"Error deleting sqlite file: %@", anError);
        }
        NSString *aWalPath = [[aStoreURL path] stringByAppendingString:@"-wal"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:aWalPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:aWalPath error:&anError];
        }
        if (anError) {
            NSLog(@"Error deleting sqlite -wal file: %@", anError);
        }
    }
    
    // Re-setup
    [self setUpContexts];
}

#pragma mark - Save

- (void)saveDefaultContextWithCompletionBlock:(void (^)(BOOL theSuccessFlag, NSError *theError))theCompletionBlock
{
    [self.defaultContext performBlock:^{
        
        NSError *anError = nil;
        BOOL aSaveSuccess = [self.defaultContext save:&anError];
        if (!aSaveSuccess) {
            NSLog(@"Error saving main queue context: %@", anError);
            if (theCompletionBlock) {
                theCompletionBlock(NO, anError);
            }
            return;
        }
        
        // Save parent context
        [self.parentSaveContext performBlock:^{
            NSError *anError = nil;
            BOOL aParentSaveSuccess = [self.parentSaveContext save:&anError];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                if (!aParentSaveSuccess) {
                    NSLog(@"Error saving async parent context: %@", anError);
                    if (theCompletionBlock) {
                        theCompletionBlock(NO, anError);
                    }
                }
                else {
                    if (theCompletionBlock) {
                        theCompletionBlock(YES, nil);
                    }
                }
            }];
        }];
    }];
}

- (void)saveDefaultContext
{
    [self saveDefaultContextWithCompletionBlock:nil];
}

- (void)saveBackgroundContextWithCompletionBlock:(void (^)(BOOL theSuccessFlag, NSError *theError))completionBlock
{
    [self.backgroundContext performBlock:^{
        NSError *anError = nil;
        BOOL aSaveSuccess = [self.backgroundContext save:&anError];
        if (!aSaveSuccess) {
            NSLog(@"Error saving context: %@", anError);
        }
        // Push changes to main queue context and parent save context
        [self saveDefaultContextWithCompletionBlock:completionBlock];
    }];
}

#pragma mark - Change Blocks

- (void)performDefaultContextChangesToSave:(void (^)(NSManagedObjectContext *theDefaultContext))theChangeBlock completionBlock:(void (^)(BOOL theSuccessFlag, NSError *theError))completionBlock
{
    NSAssert(theChangeBlock, @"Change block must be provided.");
    NSAssert([NSThread isMainThread], @"Default context change blocks shoud only be called from the main queue.");
    theChangeBlock(self.defaultContext);
    [self saveDefaultContextWithCompletionBlock:completionBlock];
}

// Background context - Call from any thread. The change block is executed in a background queue so calling from the main thread doesn't block. Changes are immediately pushed up to the main queue and update the UI, and then pushed up to the async parent context and saved to the store in the background. This method is the business.
- (void)performBackgroundContextChangesToSave:(void (^)(NSManagedObjectContext *theBackgroundContext))theChangeBlock completionBlock:(void (^)(BOOL theSuccessFlag, NSError *theError))completionBlock
{
    NSAssert(theChangeBlock, @"Change block must be provided.");
    [self.backgroundContext performBlock:^{
        theChangeBlock(self.backgroundContext);
        NSError *anError = nil;
        BOOL aSaveSuccess = [self.backgroundContext save:&anError];
        if (!aSaveSuccess) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                NSLog(@"Error saving context: %@", anError);
                if (completionBlock) completionBlock(NO, anError);
            }];
            return;
        }
        // {ush changes to main queue context and parent save context
        [self saveDefaultContextWithCompletionBlock:completionBlock];
    }];
}

#pragma mark - Objects

- (id)newObjectOfClass:(Class)theClass inContext:(NSManagedObjectContext *)theMOC
{
    NSString *anEntityName = [(id)theClass entityName];
    NSManagedObject *anObject = [NSEntityDescription insertNewObjectForEntityForName:anEntityName inManagedObjectContext:theMOC];
    return anObject;
}

- (id)objectWithValue:(id)theValue forKey:(NSString *)theKey ofClass:(Class)theClass inContext:(NSManagedObjectContext *)theMOC shouldInsert:(BOOL)theShouldInsertFlag
{
    NSArray *anObjectArray = [self objectsWithValue:theValue forKey:theKey ofClass:theClass inContext:theMOC];
    NSAssert(anObjectArray.count <= 1, @"Found more than one result that matches a unique ID");
    if (!anObjectArray) {
        NSLog(@"Error encountered fetching object with value: %@ - for key: %@", theValue, theKey);
        return nil;
    }
    NSAssert([theClass respondsToSelector:@selector(entityName)], @"Class doesn't respond to -entityName");
    NSManagedObject *anObject = [anObjectArray firstObject];
    if (!anObject && theShouldInsertFlag) {
        NSString *anEntityName = [(id)theClass entityName];
        anObject = [NSEntityDescription insertNewObjectForEntityForName:anEntityName inManagedObjectContext:theMOC];
    }
    return anObject;
}

- (id)objectsOfClass:(Class)theClass predicate:(NSPredicate *)thePredicate sortDescriptors:(NSArray *)theSortDescriptors inContext:(NSManagedObjectContext *)theMOC
{
    NSAssert([theClass respondsToSelector:@selector(entityName)], @"Class doesn't respond to -entityName");
    NSString *anEntityName = [(id)theClass entityName];
    NSFetchRequest *aFetchRequest = [NSFetchRequest fetchRequestWithEntityName:anEntityName];
    if (thePredicate) {
        aFetchRequest.predicate = thePredicate;
    }
    if (theSortDescriptors) {
        aFetchRequest.sortDescriptors = theSortDescriptors;
    }
    NSError *anError = nil;
    NSArray *anObjectArray = [theMOC executeFetchRequest:aFetchRequest error:&anError];
    if (!anObjectArray) {
        NSLog(@"Error encountered executing fetch-request: %@", anError);
        return nil;
    }
    return anObjectArray;
}

- (id)objectsWithValue:(id)theValue forKey:(NSString *)theKey ofClass:(Class)theClass sortDescriptors:(NSArray *)theSortDescriptors inContext:(NSManagedObjectContext *)theMOC
{
    NSPredicate *aPredicate = nil;
    if (theValue && theKey) {
        aPredicate = [NSPredicate predicateWithFormat:@"self.%@ = %@", theKey, theValue];
    }
    return [self objectsOfClass:theClass predicate:aPredicate sortDescriptors:theSortDescriptors inContext:theMOC];
}

- (id)objectsWithValue:(id)theValue forKey:(NSString *)theKey ofClass:(Class)theClass inContext:(NSManagedObjectContext *)theMOC
{
    return [self objectsWithValue:theValue forKey:theKey ofClass:theClass sortDescriptors:nil inContext:theMOC];
}

#pragma mark - NSFetchedResultsController

- (NSFetchedResultsController *)newFetchedResultsControllerWithClass:(Class)theClass predicate:(NSPredicate *)thePredicate sortDescriptors:(NSArray *)theSortDescriptors
{
    return [self newFetchedResultsControllerWithClass:theClass predicate:thePredicate sortDescriptors:theSortDescriptors context:self.defaultContext];
}

- (NSFetchedResultsController *)newFetchedResultsControllerWithClass:(Class)theClass predicate:(NSPredicate *)thePredicate sortDescriptors:(NSArray *)theSortDescriptors context:(NSManagedObjectContext *)theContext
{
    NSAssert(theSortDescriptors, @"Sort desciptors are required to make a fetch request");
    NSFetchRequest *aFetchRequest = [NSFetchRequest fetchRequestWithEntityName:[theClass entityName]];
    if (thePredicate) {
        aFetchRequest.predicate = thePredicate;
    }
    if (theSortDescriptors) {
        aFetchRequest.sortDescriptors = theSortDescriptors;
    }
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:aFetchRequest managedObjectContext:theContext sectionNameKeyPath:nil cacheName:nil];
    return aFetchedResultsController;
}

#pragma mark - Setup Stack

- (void)addPersistentStore
{
    NSAssert(self.persistentStoreCoordinator, @"Cannot add store without a PSC");
    NSURL *aStoreURL = [NSURL fileURLWithPath:self.filePath];
    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption: @YES};
    NSError *anError = nil;
    if (![self.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:aStoreURL options:options error:&anError]) {
        NSLog(@"Unresolved error %@, %@", anError, [anError userInfo]);
        NSAssert(NO, @"Failed to create persitent store. Check the model version number is set correctly");
    }
}

- (void)setUpContexts
{
    self.parentSaveContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [self.parentSaveContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    self.parentSaveContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
    self.defaultContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [self.defaultContext setParentContext:self.parentSaveContext];
    self.defaultContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
    self.backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [self.backgroundContext setParentContext:self.defaultContext];
    self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    NSURL *aModelURL = [[NSBundle mainBundle] URLForResource:self.storeName withExtension:@"momd"];
    self.managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:aModelURL];
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    [self addPersistentStore];
    return _persistentStoreCoordinator;
}

@end
