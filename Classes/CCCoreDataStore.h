//
//  CCCoreDataStore.h
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

#import <CoreData/CoreData.h>

@interface CCCoreDataStore : NSObject

/**
    Returns the default, main thread context.
 
    @return NSManagedObjectContext defaultContext
 */
@property (nonatomic, readonly, strong) NSManagedObjectContext *defaultContext;

/**
    Returns the background context.
    
    @return NSManagedObjectContext background context
 */
@property (nonatomic, readonly, strong) NSManagedObjectContext *backgroundContext;

/**
    Sets up the CoreData stack.
    
    @param theName string - used to create the path to the store's sqlite & mmod files. Cannot be nil.
    
    @return an initialized CCCOreDataStore object
 */
- (instancetype)initWithStoreName:(NSString *)theName;

/**
    Sets up the CoreData stack. 
    
    @param  theName string - the name of the store, used to create a path to the mmod file & sqlite file. Cannot be nil.
    @param theBOOL - if yes, will delete any existing store from disk.
 
    @return an initialized CCCOreDataStoreObject
 */
- (instancetype)initWithStoreName:(NSString *)theName shouldDeleteCurrentStore:(BOOL)theBool;

/**
    Tears down and re-sets up the CoreData stack. 
 */
- (void)resetContext;

/**
    Tears down and re-sets up the CoreData stack. Deletes the existing store from disk. 
 */
- (void)resetStore;

/**
    Save changes to the main thread context. 
 */
- (void)saveDefaultContext;

/**
    Save changes to the main thread context with completion block. 
 
    @param theCompletionBlock - the block to call when the save is complete, or nil.
 */
- (void)saveDefaultContextWithCompletionBlock:(void (^)(BOOL theSuccessFlag, NSError *theError))theCompletionBlock;

/**
    Save changes to the background context with completion block. Changes saved here will propagate to the main thread context. 
 
    @param theCompletionBlock - the block to call when the save is complete, or nil.
 */
- (void)saveBackgroundContextWithCompletionBlock:(void (^)(BOOL theSuccessFlag, NSError *theError))completionBlock;

/**
    Perform background context changes in block 
    
    @param theChangeBlock - the block with changes to be called in background. Cannot be nil.
    @param theCompletinoBlock - the blcok to call when the changes have been saved, or nil.
 */
- (void)performBackgroundContextChangesToSave:(void (^)(NSManagedObjectContext *theBackgroundContext))theChangeBlock completionBlock:(void (^)(BOOL theSuccessFlag, NSError *theError))completionBlock;

/**
    Perform main thread context changes in block 
    
    @param theChangeBlock - the block with changes to be called on main thread. Cannot be nil.
    @param theCompletionBlock - the block that will be called when changes are complete, or nil.
 */
- (void)performDefaultContextChangesToSave:(void (^)(NSManagedObjectContext *theDefaultContext))theChangeBlock completionBlock:(void (^)(BOOL theSuccessFlag, NSError *theError))completionBlock;

/**
    Returns a newly created NSManagedObject of the given class in the given context.
 
    @return a newly initialized object of the class 'theClass'
 
    @param Class the class of the NSManagedObject to create
    @param theMOC the NSManagedObjectContext to create the object with
 */
- (id)newObjectOfClass:(Class)theClass inContext:(NSManagedObjectContext *)theMOC;

/**
    Returns a NSManagedObject, fetched in the given context. If shouldInsert is YES, will create an object if none exists that already satisfies the given arguments 
    
    @return an object of class 'theClass'
 
    @param theValue - a string value of the key/value pair to check, or nil.
    @param theKey - a string key of the key/value pair to check, or nil.
    @param theClass - the class of the object that will be returned. Cannot be nil.
    @param theMOC - the context in which to fetch/create the object. Cannot be nil.
    @param theShouldInsertFlag - a boolean indicating if a new object should be created if an existing one isn't found satisfying the arguments
 */
- (id)objectWithValue:(id)theValue forKey:(NSString *)theKey ofClass:(Class)theClass inContext:(NSManagedObjectContext *)theMOC shouldInsert:(BOOL)theShouldInsertFlag;

/**
    Returns an array of NSManagedObjects, fetched in the given context

    @return an array of objects of class 'theClass'

    @param theValue - a string value of the key/value pair to check, or nil.
    @param theKey - a string key of the key/value pair to check, or nil.
    @param theClass - the class of the objects that will be returned. Cannot be nil.
    @param theMOC - the context in which to fetch/create the object. Cannot be nil.
 */
- (id)objectsWithValue:(id)theValue forKey:(NSString *)theKey ofClass:(Class)theClass inContext:(NSManagedObjectContext *)theMOC;

/**
    Returns an array of NSManagedObjects, fetched in the given context

    @return an array of objects of class 'theClass'

    @param theValue - a string value of the key/value pair to check, or nil.
    @param theKey - a string key of the key/value pair to check, or nil.
    @param theClass - the class of the objects that will be returned. Cannot be nil.
    @param theSortDescriptors - an array of NSSortDescriptors to use in the fetch, or nil.
    @param theMOC - the context in which to fetch/create the object. Cannot be nil.
 */
- (id)objectsWithValue:(id)theValue forKey:(NSString *)theKey ofClass:(Class)theClass sortDescriptors:(NSArray *)theSortDescriptors inContext:(NSManagedObjectContext *)theMOC;

/**
    Returns an array of NSManagedObjects, fetched in the given context

    @return an array of objects of class 'theClass'

    @param theClass - the class of the objects that will be returned. Cannot be nil.
    @param thePredicate - an NSPredicate to use in the fetch, or nil.
    @param theSortDescriptors - an array of NSSortDescriptors to use in the fetch, or nil.
    @param theMOC - the context in which to fetch/create the object. Cannot be nil.
 */
- (id)objectsOfClass:(Class)theClass predicate:(NSPredicate *)thePredicate sortDescriptors:(NSArray *)theSortDescriptors inContext:(NSManagedObjectContext *)theMOC;


/**
    Returns a newly created NSFetchedResultsController
 
    @return NSFetchedResultsController
 
    @param theEntityName - the entity name string of the objects that will be fetched by the controller. Cannot be nil.
    @param thePredicate - an NSPredicate to use use in the fetch, or nil.
    @param theSortDescriptors - an array of NSSortDescriptors to use in the fetch, or nil.
 */
- (NSFetchedResultsController *)newFetchedResultsControllerWithEntityName:(NSString *)theEntityName predicate:(NSPredicate *)thePredicate sortDescriptors:(NSArray *)theSortDescriptors;

@end
