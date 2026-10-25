import hashlib, hmac, secrets

def hash_password(password: str) -> str:
    salt=secrets.token_hex(16)
    digest=hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 240000).hex()
    return f"pbkdf2_sha256${salt}${digest}"

def verify_password(password: str, stored: str) -> bool:
    try:
        _,salt,digest=stored.split('$',2)
        candidate=hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 240000).hex()
        return hmac.compare_digest(candidate,digest)
    except Exception: return False
