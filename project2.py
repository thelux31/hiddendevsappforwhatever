import discord  # Main Discord.py library
from discord.ext import commands  # Command extension for easier bot creation
from discord import app_commands  # For slash commands
import random  # To select random trivia questions
import time  # To measure latency
import os  # For environment variables
from dotenv import load_dotenv  # To securely load .env file

# Load environment variables from .env
load_dotenv()

# Configure bot intents (permissions)
# Intents allow the bot to access messages, reactions, member info, etc.
intents = discord.Intents.all()  # Using all intents for demonstration

# Initialize bot with a prefix (optional, slash commands are used)
bot = commands.Bot(command_prefix="!", intents=intents)

# List of trivia questions with answers
TRIVIA_QUESTIONS = [
    {"question": "What is the capital of France?", "answer": "Paris"},
    {"question": "Which planet is known as the Red Planet?", "answer": "Mars"},
    {"question": "Who wrote '1984'?", "answer": "George Orwell"},
    {"question": "What is the largest ocean on Earth?", "answer": "Pacific"},
    {"question": "What is the chemical symbol for gold?", "answer": "Au"},
]

# Event: triggered when the bot is fully connected and ready
@bot.event
async def on_ready():
    # Sync slash commands to a specific guild (for testing, can be siwtch to bot.tree.sync if preffered)
    await bot.tree.sync(guild=discord.Object(id=int(os.getenv("GUILD_ID"))))
    
    # Print bot login confirmation in console
    print(f"Logged in as {bot.user}")

# Checks bot latency (command)
@bot.tree.command(name="ping", description="Check bot latency")
async def ping(interaction: discord.Interaction):
    # Record start time
    start_time = time.perf_counter()

    # Send preliminary message
    await interaction.response.send_message("Pinging...")

    # Record end time
    end_time = time.perf_counter()

    # Websocket latency in milliseconds
    websocket_latency = round(bot.latency * 1000)

    # Response latency in milliseconds
    response_latency = round((end_time - start_time) * 1000)

    # Edit original message to show latencies
    await interaction.edit_original_response(
        content=(
            f"Websocket latency: **{websocket_latency} ms**\n"
            f"Response latency: **{response_latency} ms**"
        )
    )

# Command: /trivia
# Starts a simple trivia question
@bot.tree.command(name="trivia", description="Start a trivia question")
async def trivia(interaction: discord.Interaction):
    # Randomly select a trivia question from the list
    question_data = random.choice(TRIVIA_QUESTIONS)
    question_text = question_data["question"]
    correct_answer = question_data["answer"]

    # Send the trivia question to the user
    await interaction.response.send_message(f"Time for Trivia! \n**{question_text}**")

    # Function to check that response is from the same user and channel
    def check(msg):
        return msg.author == interaction.user and msg.channel == interaction.channel

    try:
        # Wait for a response from the user for 10 seconds
        user_response = await bot.wait_for("message", timeout=10.0, check=check)

        # Compare user's answer to correct answer (case insensitive)
        if user_response.content.strip().lower() == correct_answer.lower():
            await interaction.followup.send(f"Correct! The answer was **{correct_answer}**.")
        else:
            await interaction.followup.send(f"❌ The correct answer was **{correct_answer}**.")

    except Exception:
        # Triggered if user does not respond in time
        await interaction.followup.send("Time out! Try again next time.")

# Run the bot using the token from .env
bot.run(os.getenv("TOKEN"))
