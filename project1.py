import discord  # Main Discord.py library
from discord.ext import commands  # Command extension for easier bot creation
from discord import app_commands  # For slash commands
import os  # For environment variables
from dotenv import load_dotenv  # To securely load .env file
from datetime import timedelta  # To set timeout durations

# Load environment variables from .env
load_dotenv()

# Configure bot intents (permissions)
# Intents allow the bot to access member info, messages, etc.
intents = discord.Intents.all()

# Initialize the bot with a prefix (optional, slash commands are used)
bot = commands.Bot(command_prefix="!", intents=intents)

# Event: triggered when the bot is fully connected and ready
@bot.event
async def on_ready():
    # Sync slash commands to a specific guild (for testing)
    await bot.tree.sync(guild=discord.Object(id=int(os.getenv("GUILD_ID"))))
    
    # Print bot login confirmation
    print(f"Logged in as {bot.user}")

# Command: /kick
# Removes a member from the server
@bot.tree.command(name="kick", description="Kick a member from the server")
@app_commands.describe(member="Member to kick", reason="Reason for kick")
async def kick(interaction: discord.Interaction, member: discord.Member, reason: str = "No reason provided"):
    # Check if the user has kick permissions
    if not interaction.user.guild_permissions.kick_members:
        await interaction.response.send_message("You do not have permission to kick members.", ephemeral=True)
        return

    # Attempt to kick the member
    try:
        await member.kick(reason=reason)
        await interaction.response.send_message(f"{member.mention} was kicked. Reason: {reason}")
    except Exception as e:
        await interaction.response.send_message(f"Could not kick {member.mention}. Error: {e}", ephemeral=True)

# Command: /ban
# Bans a member from the server
@bot.tree.command(name="ban", description="Ban a member from the server")
@app_commands.describe(member="Member to ban", reason="Reason for ban")
async def ban(interaction: discord.Interaction, member: discord.Member, reason: str = "No reason provided"):
    # Check if the user has ban permissions
    if not interaction.user.guild_permissions.ban_members:
        await interaction.response.send_message("You do not have permission to ban members.", ephemeral=True)
        return

    # Attempt to ban the member
    try:
        await member.ban(reason=reason)
        await interaction.response.send_message(f"{member.mention} was banned. Reason: {reason}")
    except Exception as e:
        await interaction.response.send_message(f"Could not ban {member.mention}. Error: {e}", ephemeral=True)

# Command: /timeout
# Temporarily mutes a member for a specified duration
@bot.tree.command(name="timeout", description="Temporarily mute a member")
@app_commands.describe(member="Member to timeout", duration="Duration in minutes", reason="Reason for timeout")
async def timeout(interaction: discord.Interaction, member: discord.Member, duration: int = 5, reason: str = "No reason provided"):
    # Check if the user has manage messages permissions
    if not interaction.user.guild_permissions.moderate_members:
        await interaction.response.send_message("You do not have permission to timeout members.", ephemeral=True)
        return

    # Calculate duration as timedelta
    timeout_duration = timedelta(minutes=duration)

    # Attempt to apply timeout
    try:
        await member.edit(timed_out_until=discord.utils.utcnow() + timeout_duration, reason=reason)
        await interaction.response.send_message(f"{member.mention} was timed out for {duration} minutes. Reason: {reason}")
    except Exception as e:
        await interaction.response.send_message(f"Could not timeout {member.mention}. Error: {e}", ephemeral=True)

# Run the bot using the token from .env
bot.run(os.getenv("TOKEN"))
