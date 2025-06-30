#!/usr/bin/env python3
"""
UnCloud Password Manager Backend
A secure, self-hosted password management service
"""

import os
import logging
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_restful import Api, Resource
import psycopg2
from cryptography.fernet import Fernet
import jwt
import bcrypt
from datetime import datetime, timedelta

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)
CORS(app)
api = Api(app)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('PASSWORDMANAGER_SECRET_KEY', 'default-secret-key')
app.config['DATABASE_URL'] = os.environ.get('DATABASE_URL', 'postgresql://user:pass@localhost/db')

# Encryption key
ENCRYPTION_KEY = os.environ.get('PASSWORDMANAGER_ENCRYPTION_KEY', Fernet.generate_key())
cipher = Fernet(ENCRYPTION_KEY)

class DatabaseManager:
    """Database connection and operations manager"""
    
    def __init__(self, database_url):
        self.database_url = database_url
    
    def get_connection(self):
        """Get database connection"""
        return psycopg2.connect(self.database_url)
    
    def init_db(self):
        """Initialize database tables"""
        with self.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS users (
                        id SERIAL PRIMARY KEY,
                        username VARCHAR(255) UNIQUE NOT NULL,
                        password_hash VARCHAR(255) NOT NULL,
                        email VARCHAR(255),
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """)
                
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS passwords (
                        id SERIAL PRIMARY KEY,
                        user_id INTEGER REFERENCES users(id),
                        title VARCHAR(255) NOT NULL,
                        username VARCHAR(255),
                        encrypted_password TEXT NOT NULL,
                        url VARCHAR(500),
                        notes TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """)
                conn.commit()

# Initialize database
db = DatabaseManager(app.config['DATABASE_URL'])

class HealthCheck(Resource):
    """Health check endpoint"""
    
    def get(self):
        return {'status': 'healthy', 'service': 'password-manager-backend'}

class AuthResource(Resource):
    """Authentication endpoints"""
    
    def post(self):
        """Login endpoint"""
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')
        
        if not username or not password:
            return {'error': 'Username and password required'}, 400
        
        try:
            with db.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT id, password_hash FROM users WHERE username = %s", (username,))
                    result = cur.fetchone()
                    
                    if result and bcrypt.checkpw(password.encode('utf-8'), result[1].encode('utf-8')):
                        user_id = result[0]
                        token = jwt.encode(
                            {
                                'user_id': user_id,
                                'username': username,
                                'exp': datetime.utcnow() + timedelta(hours=24)
                            },
                            app.config['SECRET_KEY'],
                            algorithm='HS256'
                        )
                        return {'token': token, 'user_id': user_id}
                    else:
                        return {'error': 'Invalid credentials'}, 401
        except Exception as e:
            logger.error(f"Login error: {e}")
            return {'error': 'Internal server error'}, 500

class PasswordResource(Resource):
    """Password management endpoints"""
    
    def get(self):
        """Get passwords for authenticated user"""
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        
        if not token:
            return {'error': 'Authentication required'}, 401
        
        try:
            payload = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            user_id = payload['user_id']
            
            with db.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        SELECT id, title, username, encrypted_password, url, notes, created_at, updated_at
                        FROM passwords WHERE user_id = %s ORDER BY updated_at DESC
                    """, (user_id,))
                    
                    passwords = []
                    for row in cur.fetchall():
                        # Decrypt password
                        decrypted_password = cipher.decrypt(row[3].encode()).decode()
                        
                        passwords.append({
                            'id': row[0],
                            'title': row[1],
                            'username': row[2],
                            'password': decrypted_password,
                            'url': row[4],
                            'notes': row[5],
                            'created_at': row[6].isoformat(),
                            'updated_at': row[7].isoformat()
                        })
                    
                    return {'passwords': passwords}
        except jwt.ExpiredSignatureError:
            return {'error': 'Token expired'}, 401
        except jwt.InvalidTokenError:
            return {'error': 'Invalid token'}, 401
        except Exception as e:
            logger.error(f"Get passwords error: {e}")
            return {'error': 'Internal server error'}, 500
    
    def post(self):
        """Create new password entry"""
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        
        if not token:
            return {'error': 'Authentication required'}, 401
        
        data = request.get_json()
        title = data.get('title')
        username = data.get('username')
        password = data.get('password')
        url = data.get('url', '')
        notes = data.get('notes', '')
        
        if not title or not password:
            return {'error': 'Title and password required'}, 400
        
        try:
            payload = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            user_id = payload['user_id']
            
            # Encrypt password
            encrypted_password = cipher.encrypt(password.encode()).decode()
            
            with db.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        INSERT INTO passwords (user_id, title, username, encrypted_password, url, notes)
                        VALUES (%s, %s, %s, %s, %s, %s) RETURNING id
                    """, (user_id, title, username, encrypted_password, url, notes))
                    
                    password_id = cur.fetchone()[0]
                    conn.commit()
                    
                    return {'id': password_id, 'message': 'Password created successfully'}
        except jwt.ExpiredSignatureError:
            return {'error': 'Token expired'}, 401
        except jwt.InvalidTokenError:
            return {'error': 'Invalid token'}, 401
        except Exception as e:
            logger.error(f"Create password error: {e}")
            return {'error': 'Internal server error'}, 500

# Register API resources
api.add_resource(HealthCheck, '/health')
api.add_resource(AuthResource, '/auth/login')
api.add_resource(PasswordResource, '/passwords')

@app.route('/')
def index():
    """Root endpoint"""
    return jsonify({
        'service': 'UnCloud Password Manager Backend',
        'version': '1.0.0',
        'status': 'running'
    })

if __name__ == '__main__':
    # Initialize database
    try:
        db.init_db()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
    
    # Run the application
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False) 