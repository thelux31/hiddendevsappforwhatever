# Imports
import discord
from discord.ext import commands
from discord import app_commands
from deep_translator import GoogleTranslator
import time
import random
from dotenv import *
import os

# Load dotenv
load_dotenv()

# Basic Setup
intents = discord.Intents.all()
bot = commands.Bot(command_prefix="!", intents=intents)

# On Ready Event
@bot.event
async def on_ready():
    await bot.tree.sync(guild=discord.Object(id=1400070997452918855))
    print(f"Logged in as {bot.user}")

@bot.tree.command(name="translate", description="Translate a message")  # Define a slash command named "translate"
@app_commands.describe(
    text="Text you want to translate",  # Describe the 'text' parameter for Discord UI
    target_lang="Target language code (e.g. en, pt, fr, es)"  # Describe the 'target_lang' parameter
)
async def translate(
    interaction: discord.Interaction,  # The Discord interaction object
    text: str,  # Text to be translated
    target_lang: str  # Target language code
):
    try:
        translated_text = GoogleTranslator(
            source="auto",  # Detect the source language automatically
            target=target_lang.lower()  # Set the target language to the provided code
        ).translate(text)  # Perform the translation

        await interaction.response.send_message(
            f"**Translated ({target_lang.upper()}):**\n{translated_text}",  # Send translated text
            ephemeral=False  # Make the message visible to everyone in the channel
        )

    except Exception:  # Handle any errors that occur during translation
        await interaction.response.send_message(
            "Translation failed. Make sure the language code is valid. "
            "If this persists, the issue is internal.",  # Inform user of failure
            ephemeral=True  # Make the error message visible only to the user
        )

@bot.tree.command(name="ping", description="Check the bot's latency!")  # Define a slash command to check latency
async def ping(interaction: discord.Interaction):  # Function triggered when /ping is used
    start_time = time.perf_counter()  # Record the current time before sending a message

    await interaction.response.send_message("Pinging...")  # Send initial message to acknowledge interaction

    end_time = time.perf_counter()  # Record the time after message is sent

    websocket_latency = round(bot.latency * 1000)  # Convert websocket latency to milliseconds
    response_latency = round((end_time - start_time) * 1000)  # Calculate response latency in milliseconds

    await interaction.edit_original_response(
        content=(
            f"Websocket latency: **{websocket_latency} ms**\n"  # Display websocket latency
            f"Response latency: **{response_latency} ms**"  # Display response latency
        )
    )

@bot.tree.command(name="coinflip", description="Flip a coin (Heads or Tails!)") # Command to Flip a coin (basically head or tails)
async def coinflip(interaction: discord.Interaction): # Acknowledge Interaction
    result = random.choice(["Heads", "Tails"]) # Picks something random using the random module
    await interaction.response.send_message(f"The choice was... **{result}**") # Results

bot.run(os.getenv("TOKEN")) # Start the bot (gets token from the env file)
