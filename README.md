# Controlling Audio with SiriKit

Control audio playback and handle add media requests using SiriKit Media Intents

## Overview

This sample code project is associated with WWDC 2019 session 207: Introducing SiriKit Media Intents (https://developer.apple.com/videos/play/wwdc19/207/).

## Configure the Sample Code Project

Before you run the sample code project in Xcode:

Step 1. Create an App Group for com.example.apple-samplecode.ControlAudio.Shared in your developer portal

Step 2. Create an App ID for com.example.apple-samplecode.ControlAudio in your developer portal, enabling it for App Groups (to the app group created in step 1), and SiriKit

Step 3. Create a Music ID for music.com.example.apple-samplecode.ControlAudio in your developer portal

Step 4. Create a Key for the MusicKit service and create a developer token via the steps on https://developer.apple.com/documentation/applemusicapi/getting_keys_and_creating_tokens

Step 5. Copy this developer token to the developerToken variable in the MusicKitAPIController.swift file

Step 6. Create a provisioning profile for com.example.apple-samplecode.ControlAudio and com.example.apple-samplecode.ControlAudio.ControlAudioExtension in your developer portal

Step 7. Associate these provisioning profiles with the project in Xcode signing settings
	
	
	
