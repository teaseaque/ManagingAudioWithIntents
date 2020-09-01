/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file implements the AppDelegate callback methods for the intent handling via background app launch
*/
import os.log
import UIKit
import Intents
import MediaPlayer
import CoreSpotlight

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    var appleMusicAPIController: AppleMusicAPIController?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Set our playlist title in AppIntentVocabulary.plist so we get the proper Siri intent.
        // In your app, you'll want to make this dynamically tuned to a user's playlist titles.
        let vocabulary = INVocabulary.shared()
        let playlistNames = NSOrderedSet(objects: "70s punk classics")
        vocabulary.setVocabularyStrings(playlistNames, of: .mediaPlaylistTitle)
        
        // Create an instance of INMediaUserContext to increase the likelihood
        // of the system sending intents that don't include an app name to this app.
        DispatchQueue.global(qos: .userInitiated).async {
            let context = INMediaUserContext()
            context.numberOfLibraryItems = MPMediaQuery.songs().items?.count
            
            // Create the Apple Music API controller to request StoreKit authorization, then fetch the user token and prepare for artwork fetches.
            let controller = AppleMusicAPIController()
            controller.prepareForRequests { success in
                
                if success {
                    self.appleMusicAPIController = controller
                    
                    context.subscriptionStatus = .subscribed
                    
                    // Now that artwork can be fetched, allow the view controller to reload its media item state.
                    DispatchQueue.main.async {
                        let viewController = self.window?.rootViewController as? ViewController
                        viewController?.updateMediaItemState()
                    }
                } else {
                    context.subscriptionStatus = .notSubscribed
                }
                
                context.becomeCurrent()
            }
        }
        return true
    }
    
    func handlePlayMediaIntent(_ intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        // Extract the first media item from the intent's media items (these will have been resolved in the extension).
        guard let mediaItem = intent.mediaItems?.first, let identifier = mediaItem.identifier else {
            return
        }
        
        // Get the appropriate domain for Spotlight search.
        func domainForType(type: INMediaItemType) -> String {
            return type == .playlist ? "MPMediaGrouping.playlist" :
            type == .album ? "MPMediaGrouping.album" : "MPMediaGrouping.song"
        }
        
        let player = MPMusicPlayerController.systemMusicPlayer
        
        // Check if this media item is a playlist and if it's identifier has the local library prefix.
        if mediaItem.type == .playlist, let range = identifier.range(of: MediaPlayerUtilities.LocalLibraryIdentifierPrefix) {
            // Extract the persistentID for the local playlist and look it up in the library.
            guard let persistentID = UInt64(identifier[range.upperBound...]),
                let playlist = MediaPlayerUtilities.searchForPlaylistInLocalLibrary(byPersistentID: persistentID) else {
                return
            }
            
            // Set the player queue to the local playlist.
            player.setQueue(with: playlist)
            
            // Add the items from the Playlist to Spotlight Search so users can directly play the songs with your app.
            CSSearchableIndex.default().indexSearchableItems(playlist.items.compactMap({ (playlistItem) -> CSSearchableItem? in
                let attributes = CSSearchableItemAttributeSet(contentType: .audio)
                attributes.title = playlistItem.title
                attributes.artist = playlistItem.artist
                attributes.album = playlistItem.albumTitle
                attributes.genre = playlistItem.genre
                attributes.playCount = NSNumber(value: playlistItem.playCount)
                attributes.lastUsedDate = playlistItem.lastPlayedDate
                return CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: domainForType(type: mediaItem.type), attributeSet: attributes)
            }), completionHandler: nil)
            
        } else {
            // Reset the player queue to the store identifier; this could be a song, album or playlist.
            player.setQueue(with: [identifier])
            
            // Add the item from the Playlist to Spotlight Search so users can directly play the songs with your app.
            let attributes = CSSearchableItemAttributeSet(contentType: .audio)
            attributes.title = mediaItem.title
            attributes.artist = mediaItem.artist
            let item = CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: domainForType(type: mediaItem.type), attributeSet: attributes)
            CSSearchableIndex.default().indexSearchableItems([item], completionHandler: nil)
        }
        
        player.prepareToPlay { error in
            if let error = error {
                os_log("Failed to prepare to play error: %{public}@", log: OSLog.default, type: .error, error.localizedDescription)
                completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
            } else {
                DispatchQueue.main.async {
                    player.play()
                }
                
                let response = INPlayMediaIntentResponse(code: .success, userActivity: nil)
                
                // Donate an interaction to the system.
                let interaction = INInteraction(intent: intent, response: response)
                interaction.donate(completion: nil)
                
                completion(response)
            }
        }
    }
    
    // This method is called when the application is background launched in response to the extension returning .handleInApp.
    func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
        guard let playMediaIntent = intent as? INPlayMediaIntent else {
            completionHandler(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
            return
        }
        handlePlayMediaIntent(playMediaIntent, completion: completionHandler)
    }
    
    // This is a convenience method for looking up the artwork URL for an Apple Music item and converting that to an
    // appropriately sized UIImage for display in the application's main view.
    func fetchUIImageForIdentifier(_ identifier: String?, ofSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        guard let resolvedIdentifier = identifier, let resolvedAppleMusicAPIController = appleMusicAPIController else {
            completion(nil)
            return
        }
        
        // Fetch the song via its store identifier.
        resolvedAppleMusicAPIController.fetchSongByIdentifier(resolvedIdentifier, completion: { optionalSong in
            guard let song = optionalSong, var artworkURLString = song.attributes?.artwork.url else {
                completion(nil)
                return
            }
            
            // Convert the placeholder value in the URL to the size required.
            artworkURLString = artworkURLString.replacingOccurrences(of: "{w}x{h}", with: String(format: "%.0fx%.0f", ofSize.width, ofSize.height))
            
            guard let artworkURL = URL(string: artworkURLString) else {
                completion(nil)
                return
            }
            
            // Execute a network fetch for the artwork URL.
            URLSession.shared.dataTask(with: URLRequest(url: artworkURL)) { data, response, error in
                guard let urlResponse = response as? HTTPURLResponse, urlResponse.statusCode == 200, let resolvedData = data else {
                    let errorString = error?.localizedDescription ?? "<unknown>"
                    os_log("Failed to fetch artwork data error: %{public}@", log: OSLog.default, type: .error, errorString)
                    completion(nil)
                    return
                }
                
                // Convert the data to a UIImage and call the completion handler.
                let image = UIImage(data: resolvedData)
                completion(image)
            }.resume()
        })
    }
}

