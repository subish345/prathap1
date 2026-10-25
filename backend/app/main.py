from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator
from typing import Optional
import re, secrets, sqlite3
from dotenv import load_dotenv
from .db import connect, init_db
from .security import hash_password, verify_password

load_dotenv(); init_db()
app=FastAPI(title='DrivePlus API', version='1.0.0', description='Vehicle, reminders, trips and emergency support API')
app.add_middleware(CORSMiddleware, allow_origins=['*'], allow_credentials=False, allow_methods=['*'], allow_headers=['*'])

EMAIL_RE=re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')

def clean_email(v: str) -> str:
    # Format check only. No Gmail/email verification, no confirmation mail is sent.
    v=(v or '').strip().lower()
    if not EMAIL_RE.match(v): raise ValueError('Enter a valid Gmail / email address')
    return v

class RegisterIn(BaseModel):
    email: str; password: str=Field(min_length=6); full_name: str=''
    _check_email=field_validator('email')(clean_email)
class LoginIn(BaseModel):
    email: str; password: str
    _check_email=field_validator('email')(clean_email)
class VehicleIn(BaseModel): brand: str; model: str; year: Optional[int]=None; registration_number: str; tank_capacity: Optional[float]=None; photo_uri: str=''
class ReminderIn(BaseModel): title: str; due_date: str; category: str='service'; vehicle_id: Optional[int]=None; notes: str=''
class TripIn(BaseModel): origin: str; destination: str; distance_km: float=Field(gt=0); fuel_efficiency: float=Field(gt=0); fuel_price: float=Field(gt=0)
class SosIn(BaseModel): latitude: Optional[float]=None; longitude: Optional[float]=None; message: str='Emergency assistance requested'

def user_from(auth):
    # Starter auth: token is user id plus a random session key. Replace with signed JWT/OAuth for production.
    if not auth or not auth.lower().startswith('bearer '): raise HTTPException(401,'Sign in required')
    try: uid=int(auth.split()[1].split('.')[0])
    except: raise HTTPException(401,'Invalid session')
    with connect() as c: row=c.execute('SELECT id,email,full_name FROM users WHERE id=?',(uid,)).fetchone()
    if not row: raise HTTPException(401,'Invalid session')
    return dict(row)

@app.get('/health')
def health(): return {'status':'ok','service':'DrivePlus API'}

@app.post('/auth/register')
def register(data:RegisterIn):
    # Gmail/email + password are saved straight into the users table of the SQLite database.
    name=data.full_name.strip()
    try:
        with connect() as c:
            cur=c.execute('INSERT INTO users(email,password_hash,full_name) VALUES(?,?,?)',(data.email,hash_password(data.password),name))
            uid=cur.lastrowid
    except sqlite3.IntegrityError:
        raise HTTPException(409,'An account with this email already exists')
    except Exception:
        raise HTTPException(400,'Could not create account')
    return {'id':uid,'email':data.email,'full_name':name,'token':f'{uid}.{secrets.token_urlsafe(24)}'}

@app.post('/auth/login')
def login(data:LoginIn):
    # Login is checked directly against the credentials stored in the database.
    with connect() as c: row=c.execute('SELECT * FROM users WHERE email=?',(data.email,)).fetchone()
    if not row: raise HTTPException(404,'No account found for this email. Please register first.')
    if not verify_password(data.password,row['password_hash']): raise HTTPException(401,'Incorrect password')
    return {'id':row['id'],'email':row['email'],'full_name':row['full_name'],'token':f"{row['id']}.{secrets.token_urlsafe(24)}"}

@app.get('/profile')
def profile(authorization: str|None=Header(default=None)):
    return user_from(authorization)

@app.get('/vehicles')
def vehicles(authorization: str|None=Header(default=None)):
    u=user_from(authorization)
    with connect() as c: rows=c.execute('SELECT * FROM vehicles WHERE user_id=? ORDER BY id DESC',(u['id'],)).fetchall()
    return [dict(r) for r in rows]

@app.post('/vehicles')
def add_vehicle(data:VehicleIn,authorization: str|None=Header(default=None)):
    u=user_from(authorization)
    with connect() as c:
        cur=c.execute('INSERT INTO vehicles(user_id,brand,model,year,registration_number,tank_capacity,photo_uri) VALUES(?,?,?,?,?,?,?)',(u['id'],data.brand,data.model,data.year,data.registration_number.upper(),data.tank_capacity,data.photo_uri))
        return dict(c.execute('SELECT * FROM vehicles WHERE id=?',(cur.lastrowid,)).fetchone())

@app.delete('/vehicles/{vehicle_id}')
def delete_vehicle(vehicle_id:int,authorization: str|None=Header(default=None)):
    u=user_from(authorization)
    with connect() as c: cur=c.execute('DELETE FROM vehicles WHERE id=? AND user_id=?',(vehicle_id,u['id']))
    if cur.rowcount==0: raise HTTPException(404,'Vehicle not found')
    return {'deleted':True}

@app.get('/reminders')
def reminders(authorization: str|None=Header(default=None)):
    u=user_from(authorization)
    with connect() as c: rows=c.execute('SELECT r.*,v.brand,v.model FROM reminders r LEFT JOIN vehicles v ON r.vehicle_id=v.id WHERE r.user_id=? ORDER BY r.due_date',(u['id'],)).fetchall()
    return [dict(r) for r in rows]

@app.post('/reminders')
def add_reminder(data:ReminderIn,authorization: str|None=Header(default=None)):
    u=user_from(authorization)
    with connect() as c:
        cur=c.execute('INSERT INTO reminders(user_id,vehicle_id,title,due_date,category,notes) VALUES(?,?,?,?,?,?)',(u['id'],data.vehicle_id,data.title,data.due_date,data.category,data.notes))
        return dict(c.execute('SELECT * FROM reminders WHERE id=?',(cur.lastrowid,)).fetchone())

@app.post('/trips')
def save_trip(data:TripIn,authorization: str|None=Header(default=None)):
    u=user_from(authorization); cost=(data.distance_km/data.fuel_efficiency)*data.fuel_price
    with connect() as c:
        cur=c.execute('INSERT INTO trips(user_id,origin,destination,distance_km,fuel_efficiency,fuel_price,estimated_cost) VALUES(?,?,?,?,?,?,?)',(u['id'],data.origin,data.destination,data.distance_km,data.fuel_efficiency,data.fuel_price,cost))
        return {'id':cur.lastrowid,'distance_km':data.distance_km,'fuel_litres':round(data.distance_km/data.fuel_efficiency,2),'estimated_cost':round(cost,2)}

@app.get('/mechanics/nearby')
def mechanics(latitude:float,longitude:float,radius_km:float=15):
    # Replace with Places API/provider integration for real, ranked results.
    return {'provider':'placeholder','items':[],'message':'Configure Google Places API or a local service provider to return nearby mechanics.','search_center':{'latitude':latitude,'longitude':longitude},'radius_km':radius_km}

@app.get('/alerts')
def alerts(latitude:Optional[float]=None,longitude:Optional[float]=None):
    # Connect to official government disaster-alert feeds for verified live alerts.
    return {'provider':'placeholder','items':[],'message':'No live alert provider configured. Connect official disaster-management feeds for verified alerts.'}

@app.post('/emergency/sos')
def sos(data:SosIn,authorization: str|None=Header(default=None)):
    u=user_from(authorization)
    # Deliberately does not contact emergency services until a verified dispatch provider is configured.
    return {'accepted':True,'status':'mock_received','message':'SOS recorded locally by API; no emergency service has been contacted. Configure a verified dispatch integration before production use.','user_id':u['id'],'latitude':data.latitude,'longitude':data.longitude}
