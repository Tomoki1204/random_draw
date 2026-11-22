import os
import asyncpg
from dotenv import load_dotenv

load_dotenv()
pool: asyncpg.Pool | None = None

async def connect():
    global pool
    url = os.environ["DATABASE_URL"]
    pool = await asyncpg.create_pool(
        url,
        min_size=1,
        max_size=10,
        ssl=None if "localhost" in url else "require",
    )

async def disconnect():
    await pool.close()