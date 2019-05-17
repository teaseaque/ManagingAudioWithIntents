/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file implements the resolution of intent parameters and the handling of intents
*/
import os.log
import Intents
import MediaPlayer

class IntentHandler: INExtension, INPlayMediaIntentHandling, INAddMediaIntentHandling {
    
    func resolveLocalPlaylistFromSearch(_ mediaSearch: INMediaSearch, completion: (INMediaItem?) -> Void) {
        // Look up playlist in the local library.
        guard let playlistName = mediaSearch.mediaName,
            let playlist = MediaPlayerUtilities.searchForPlaylistInLocalLibrary(byName: playlistName) else {
            completion(nil)
            return
        }
        
        // Construct the media item with an identifier indicating this is a local identifier.
        let persistentID = "\(MediaPlayerUtilities.LocalLibraryIdentifierPrefix)\(playlist.persistentID)"
        let mediaItem = INMediaItem(identifier: persistentID, title: playlist.name, type: .playlist, artwork: nil)
        
        completion(mediaItem)
    }

    func resolveSpecificMediaFromSearch(_ optionalMedia: Any?, completion: (INMediaItem?) -> Void) {
        guard let media = optionalMedia else {
            completion(nil)
            return
        }

        if let playlist = media as? Playlist {
            completion(INMediaItem(identifier: playlist.identifier, title: playlist.attributes?.name,
                                   type: .playlist, artwork: nil, artist: nil))
        } else if let album = media as? Album {
            let albumAttributes = album.attributes
            completion(INMediaItem(identifier: album.identifier, title: albumAttributes?.name,
                                   type: .album, artwork: nil, artist: albumAttributes?.artistName))
        } else if let song = media as? Song {
            let songAttributes = song.attributes
            completion(INMediaItem(identifier: song.identifier, title: songAttributes?.name,
                                   type: .song, artwork: nil, artist: songAttributes?.artistName))
        } else {
            completion(nil)
        }
    }
    
    func resolveMediaItem(for optionalMediaSearch: INMediaSearch?, completion: @escaping (INMediaItem?) -> Void) {
        let controller = AppleMusicAPIController()
        controller.prepareForRequests { ready in
            guard let mediaSearch = optionalMediaSearch, ready else {
                completion(nil)
                return
            }
            
            let mediaItemCompletionHandler: (INMediaItem?) -> Void = { optionalMediaItem in
                guard let mediaItem = optionalMediaItem else {
                    completion(nil)
                    return
                }
                completion(mediaItem)
            }

            // Important Note:
            // This search directly uses the strings as understood by Siri. There can be significant differences in how titles and names
            // are known in catalogs. For example punctuation, notations for guest artists [feat. XXX], soundtrack notations, homonyms, etc.
            // Developers should develop their own custom logic to have a highly robust search from Siri transcription.

            switch mediaSearch.mediaType {
            case .album:
                controller.searchForAlbum(mediaSearch.mediaName, artistName: mediaSearch.artistName, completion: { album in
                    self.resolveSpecificMediaFromSearch(album, completion: mediaItemCompletionHandler)
                })
            case .artist:
                controller.searchForArtist(mediaSearch.mediaName, completion: { media in
                    self.resolveSpecificMediaFromSearch(media, completion: mediaItemCompletionHandler)
                })
            case .song:
                let songCompletionHandler: (Song?) -> Void = { song in
                    self.resolveSpecificMediaFromSearch(song, completion: mediaItemCompletionHandler)
                }

                // If the reference is to the currently playing item and there is an identifier provided, a shortcut
                // can be taken. The item can be looked up directly by the identifier, instead of performing
                // a search based on the string parameters.
                if mediaSearch.reference == .currentlyPlaying, let identifier = mediaSearch.mediaIdentifier {
                    controller.fetchSongByIdentifier(identifier, completion: songCompletionHandler)
                } else {
                    controller.searchForSong(mediaSearch.mediaName, albumName: mediaSearch.albumName,
                                         artistName: mediaSearch.artistName, completion: songCompletionHandler)
                }
            case .music:
                fallthrough
            case .unknown:
                controller.searchForMedia(mediaSearch.mediaName, completion: { media in
                    self.resolveSpecificMediaFromSearch(media, completion: mediaItemCompletionHandler)
                })
            case .playlist:
                self.resolveLocalPlaylistFromSearch(mediaSearch, completion: completion)
            default:
                completion(nil)
            }
        }
    }
    
    /*
     * INPlayMediaIntent methods
     */

    func resolveMediaItems(for intent: INPlayMediaIntent, with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void) {
        resolveMediaItem(for: intent.mediaSearch) { optionalMediaItem in
            guard let mediaItem = optionalMediaItem else {
                completion([INPlayMediaMediaItemResolutionResult.unsupported()])
                return
            }
            completion([INPlayMediaMediaItemResolutionResult.success(with: mediaItem)])
        }
    }
    
    // The handler for INPlayMediaIntent returns the .handleInApp response code, so that the main app can be background
    // launched and begin playback. The extension is short-lived, and if playback was begun in the extension, it could
    // abruptly end when the extension is terminated by the system.
    func handle(intent: INPlayMediaIntent, completion: (INPlayMediaIntentResponse) -> Void) {
        completion(INPlayMediaIntentResponse(code: .handleInApp, userActivity: nil))
    }
    
    /*
     * INAddMediaIntent methods
     */

    func resolveMediaItems(for intent: INAddMediaIntent, with completion: @escaping ([INAddMediaMediaItemResolutionResult]) -> Void) {
        resolveMediaItem(for: intent.mediaSearch) { optionalMediaItem in
            guard let mediaItem = optionalMediaItem else {
                // Returning unsupported here will result in Siri announcing that it could not find the item in the app
                // e.g. "I couldn't find <item> on ControlAudio".
                completion([INAddMediaMediaItemResolutionResult.unsupported()])
                return
            }
            completion([INAddMediaMediaItemResolutionResult.success(with: mediaItem)])
        }
    }
    
    func resolveMediaDestination(for intent: INAddMediaIntent, with completion: @escaping (INAddMediaMediaDestinationResolutionResult) -> Void) {
        guard let mediaDestination = intent.mediaDestination else {
            completion(INAddMediaMediaDestinationResolutionResult.unsupported())
            return
        }
        
        switch mediaDestination {
        case .playlist:
            let controller = AppleMusicAPIController()
            controller.prepareForRequests { ready in
                guard let playlistName = mediaDestination.playlistName,
                    MediaPlayerUtilities.searchForPlaylistInLocalLibrary(byName: playlistName) != nil else {
                    // Returning unsupported with the .playlistNameNotFound reason will result in Siri announcing that it
                    // could not find the playlist in the app e.g. "I couldn't find the playlist named <playlistname> on ControlAudio".
                    completion(INAddMediaMediaDestinationResolutionResult.unsupported(forReason: .playlistNameNotFound))
                    return
                }
                completion(INAddMediaMediaDestinationResolutionResult.success(with: mediaDestination))
            }
        case .library:
            completion(INAddMediaMediaDestinationResolutionResult.success(with: mediaDestination))
        @unknown default:
            completion(INAddMediaMediaDestinationResolutionResult.unsupported())
        }
        
    }
    
    // Unlike the handler for the INPlayMediaIntent, the adding of media is handled here, inside of the extension,
    // as this is not a long running task and is easily handled within the lifetime of the extension.
    func handle(intent: INAddMediaIntent, completion: @escaping (INAddMediaIntentResponse) -> Void) {
        guard let mediaItem = intent.mediaItems?.first, let identifier = mediaItem.identifier else {
            completion(INAddMediaIntentResponse(code: INAddMediaIntentResponseCode.failure, userActivity: nil))
            return
        }
        
        // Add the previously resolved media item to either the library, or the specified playlist by looking at the media destination.
        switch intent.mediaDestination {
        case .library:
            MPMediaLibrary.default().addItem(withProductID: identifier) { mediaEntities, error in
                if let resolveError = error {
                    os_log("Failed to add to the library: %{public}@", log: OSLog.default, type: .error, resolveError.localizedDescription)
                    completion(INAddMediaIntentResponse(code: INAddMediaIntentResponseCode.failure, userActivity: nil))
                } else {
                    os_log("Added %{public}@: to the library", log: OSLog.default, type: .info, mediaEntities)
                    completion(INAddMediaIntentResponse(code: INAddMediaIntentResponseCode.success, userActivity: nil))
                }
            }
        case .playlist:
            guard let playlistName = intent.mediaDestination?.playlistName,
                let playlist = MediaPlayerUtilities.searchForPlaylistInLocalLibrary(byName: playlistName) else {
                os_log("Failed to add to playlist", log: OSLog.default, type: .error)
                completion(INAddMediaIntentResponse(code: INAddMediaIntentResponseCode.failure, userActivity: nil))
                return
            }
            
            playlist.addItem(withProductID: identifier, completionHandler: { error in
                if let resolvedError = error {
                    os_log("Failed %{public}@: to the %{public}@ playlist: %{public}@", log: OSLog.default,
                           type: .error, identifier, playlistName, resolvedError.localizedDescription)
                    completion(INAddMediaIntentResponse(code: INAddMediaIntentResponseCode.failure, userActivity: nil))
                } else {
                    os_log("Added %{public}@: to the %{public}@ playlist", log: OSLog.default, type: .info, identifier, playlistName)
                    completion(INAddMediaIntentResponse(code: INAddMediaIntentResponseCode.success, userActivity: nil))
                }
            })
        default:
            os_log("Unexpected media destination encountered", log: OSLog.default, type: .error)
            completion(INAddMediaIntentResponse(code: INAddMediaIntentResponseCode.failure, userActivity: nil))
        }
    }
}
