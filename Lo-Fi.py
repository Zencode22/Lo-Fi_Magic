import pygame
import numpy as np
import random
import time
from pygame import mixer

# Initialize pygame mixer
pygame.init()
mixer.init()

# Function to generate a simple sine wave sound
def generate_sound(frequency, duration, sample_rate=44100, volume=0.5):
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    note = np.sin(frequency * t * 2 * np.pi)
    audio = note * volume
    audio = np.int16(audio * 32767)
    return audio

# Function to save sound to a file
def save_sound(filename, audio, sample_rate=44100):
    pygame.sndarray.make_sound(audio).save(filename)

# Function to play the mixed song
def play_song(sounds):
    # Create a 10-second empty array for mixing
    sample_rate = 44100
    duration = 10
    mixed = np.zeros(int(sample_rate * duration), dtype=np.int16)
    
    # Mix all sounds
    for sound in sounds:
        # Load each sound
        sound_data = pygame.sndarray.array(pygame.mixer.Sound(sound))
        
        # Ensure the sound is the right length (10 seconds)
        if len(sound_data) < len(mixed):
            # Repeat the sound if it's shorter than 10 seconds
            repeats = int(len(mixed) / len(sound_data)) + 1
            sound_data = np.tile(sound_data, repeats)
        
        # Trim to 10 seconds
        sound_data = sound_data[:len(mixed)]
        
        # Mix the sound (with clipping protection)
        mixed += sound_data * 0.3  # Reduce volume to prevent clipping
    
    # Normalize to prevent clipping
    max_val = np.max(np.abs(mixed))
    if max_val > 32767:
        mixed = mixed * (32767 / max_val)
    
    # Convert to proper audio format
    mixed = np.int16(mixed)
    
    # Save and play the mixed audio
    pygame.sndarray.make_sound(mixed).play()
    pygame.time.wait(duration * 1000)  # Wait for the song to finish

# Generate some basic Lo-Fi sounds
def generate_sounds():
    sounds = []
    
    # 1. Bass sound (low frequency)
    bass = generate_sound(110, 0.5, volume=0.3)  # A2 note
    save_sound("bass.wav", bass)
    sounds.append("bass.wav")
    
    # 2. Chord sound (multiple frequencies)
    chord_duration = 1.0
    t = np.linspace(0, chord_duration, int(44100 * chord_duration), False)
    chord = (np.sin(261.63 * t * 2 * np.pi) * 0.2 +  # C4
             np.sin(329.63 * t * 2 * np.pi) * 0.2 +  # E4
             np.sin(392.00 * t * 2 * np.pi) * 0.2)   # G4
    chord = np.int16(chord * 32767 * 0.4)
    save_sound("chord.wav", chord)
    sounds.append("chord.wav")
    
    # 3. Drum beat
    drum_duration = 0.1
    t = np.linspace(0, drum_duration, int(44100 * drum_duration), False)
    # Kick drum (low frequency pulse)
    kick = np.sin(50 * t * 2 * np.pi) * np.exp(-5 * t)
    kick = np.int16(kick * 32767 * 0.5)
    save_sound("drum.wav", kick)
    sounds.append("drum.wav")
    
    # 4. Hi-hat sound (noise)
    hat_duration = 0.1
    hat = np.random.uniform(-1, 1, int(44100 * hat_duration))
    hat = hat * np.exp(-15 * np.linspace(0, 1, int(44100 * hat_duration)))
    hat = np.int16(hat * 32767 * 0.3)
    save_sound("hihat.wav", hat)
    sounds.append("hihat.wav")
    
    # 5. Melody sound (higher frequency)
    melody = generate_sound(523.25, 0.3, volume=0.4)  # C5 note
    save_sound("melody.wav", melody)
    sounds.append("melody.wav")
    
    return sounds

# Main function
def main():
    print("Welcome to the Lo-Fi Song Mixer!")
    print("Create your own 10-second Lo-Fi track by selecting three sounds to mix.")
    print()
    
    # Generate the available sounds
    available_sounds = generate_sounds()
    sound_names = ["Bass", "Chord", "Drum", "Hi-Hat", "Melody"]
    
    # Display available sounds
    print("Available sounds:")
    for i, name in enumerate(sound_names):
        print(f"{i+1}. {name}")
    print()
    
    # Let user select three sounds
    selected_sounds = []
    for i in range(3):
        while True:
            try:
                choice = int(input(f"Select sound #{i+1} (1-5): "))
                if 1 <= choice <= 5:
                    selected_sounds.append(available_sounds[choice-1])
                    print(f"Added {sound_names[choice-1]}")
                    break
                else:
                    print("Please enter a number between 1 and 5.")
            except ValueError:
                print("Please enter a valid number.")
    
    print("\nMixing your Lo-Fi song...")
    
    # Play the mixed song
    play_song(selected_sounds)
    
    print("Song finished! Thanks for using the Lo-Fi Song Mixer.")
    
    # Clean up generated sound files
    for sound_file in available_sounds:
        os.remove(sound_file)

if __name__ == "__main__":
    import os
    main()