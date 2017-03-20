//
//  SubredditManager.swift
//  Wallpaperer
//
//  Created by Joe Peplowski on 2017-03-15.
//  Copyright © 2017 Joe Peplowski. All rights reserved.
//

import Foundation

/// This class manages the user's list of Subreddits and their enabled
/// states. It also handles storage and retrieval of these arrays to and
/// from UserDefaults.

class SubredditManager {
    
    static let global = SubredditManager()
    
    private(set) var subredditNames: [String]
    private(set) var subredditEnabledStates: [Bool]
    
    
    /// Loads Subreddit names & enabled states from UserDefaults
    private init() {
        subredditNames = UserDefaults.standard.array(forKey: PreferenceKey.subreddits) as! [String]
        subredditEnabledStates = UserDefaults.standard.array(forKey: PreferenceKey.enabledSubreddits) as! [Bool]
    }
    
    
    /// Alphabetically adds a Subreddit to the user's Subreddit list
    ///
    /// - Parameters:
    ///   - name: The Subreddit's name
    ///   - enabled: Whether the Subreddit is enabled or not
    func addSubreddit(withName name: String, enabled: Bool) {
        subredditNames.append(name)
        subredditEnabledStates.append(enabled)
        sortSubredditsAlphabeticallyAndSave()
    }
    
    
    /// Removes the Subreddit at the specified index from the 
    /// user's Subreddit list
    ///
    /// - Parameter index: Index of the Subreddit to remove
    func removeSubreddit(atIndex index: Int) {
        subredditNames.remove(at: index)
        subredditEnabledStates.remove(at: index)
        
        UserDefaults.standard.set(subredditNames, forKey: PreferenceKey.subreddits)
        UserDefaults.standard.set(subredditEnabledStates, forKey: PreferenceKey.enabledSubreddits)
    }
    
    
    /// Enables/disables the Subreddit at the given index of 
    /// the user's Subreddit list
    ///
    /// - Parameters:
    ///   - index: Index of the Subreddit to enable/disable
    ///   - enabled: True to enable
    func setSubreddit(atIndex index: Int, to enabled: Bool) {
        subredditEnabledStates[index] = enabled
        UserDefaults.standard.set(subredditEnabledStates, forKey: PreferenceKey.enabledSubreddits)
    }
    
    
    /// Sorts Subreddits alphabetically and saves them to UserDefaults
    private func sortSubredditsAlphabeticallyAndSave() {
        let alphabeticalSubredditNames = subredditNames.sorted()
        var alphabeticalSubredditEnabledStates = [Bool]()
        
        for subredditName in alphabeticalSubredditNames {
            let index = subredditNames.index(of: subredditName)!
            alphabeticalSubredditEnabledStates.append(subredditEnabledStates[index])
        }
        
        subredditNames = alphabeticalSubredditNames
        subredditEnabledStates = alphabeticalSubredditEnabledStates
        
        UserDefaults.standard.set(subredditNames, forKey: PreferenceKey.subreddits)
        UserDefaults.standard.set(subredditEnabledStates, forKey: PreferenceKey.enabledSubreddits)
    }
    
    
    /// Checks if we can add the given Subreddit to the Subreddit list
    ///
    /// - Parameters:
    ///   - subreddit: The Subreddit we wish to add
    ///   - completionHandler: The appropriate AddSubredditResponse to our validity check
    func checkIfValid(_ subreddit: String, completionHandler: @escaping (_ isResponse: AddSubredditResponse) -> Void) {
        NSLog("Validating Subreddit: \(subreddit)")
        
        // Check for empty string, duplicates or invalid name
        if subreddit == "" {
            NSLog("No Subreddit specified.")
            completionHandler(.emptyString)
            return
        }
        
        let lowercaseSubreddits = subredditNames.map { $0.lowercased() }
        if lowercaseSubreddits.contains(subreddit.lowercased()) {
            NSLog("This Subreddit already exists.")
            completionHandler(.duplicate)
            return
        }
        
        let urlPath = "https://www.reddit.com/r/\(subreddit)/new.json"
        guard let url = URL(string: urlPath) else {
            NSLog("This Subreddit produces an invalid URL.")
            completionHandler(.invalidURL)
            return
        }
        
        
        // Retrieve JSON data from Reddit
        URLSession.shared.dataTask(with: url) {
            (data, response, error) in
            guard (error == nil) else {
                NSLog("There was a network error: \(String(describing: error))")
                completionHandler(.networkError)
                return
            }
            
            do {
                let jsonResult = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
                
                if jsonResult["error"] != nil {
                    NSLog("The JSON data contains an error.")
                    completionHandler(.unknownError)
                    return
                }
                
                guard let jsonData = jsonResult["data"] as? [String: AnyObject],
                    let resultsArray = jsonData["children"] else {
                        NSLog("Error parsing JSON data.")
                        completionHandler(.unknownError)
                        return
                }
                
                if (resultsArray.count > 0) {
                    NSLog("Subreddit is valid.")
                    completionHandler(.success)
                } else {
                    NSLog("Subreddit has no posts in \"new\".")
                    completionHandler(.noNewPosts)
                }
            } catch {
                NSLog("Error thrown while parsing JSON data: \(error)")
                completionHandler(.unknownError)
            }
            }.resume()
    }
    
    
    /// Creates a string of the user's enabled Subreddits separated by "+"
    ///
    /// - Returns: The string of enabled Subreddits separated by "+"
    func createSubredditURLString() -> String {
        var enabledSubreddits = [String]()
        
        for i in 0 ..< subredditNames.count {
            if subredditEnabledStates[i] {
                enabledSubreddits.append(subredditNames[i])
            }
        }
        
        return enabledSubreddits.joined(separator: "+")
    }
}
