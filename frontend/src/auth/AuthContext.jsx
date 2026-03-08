import { createContext, useContext, useState, useEffect } from 'react';
import { loginWithCredentials, apiGet } from '../api';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        const token = localStorage.getItem('token');
        const role = localStorage.getItem('role');
        if (token && role) {
            // Verify token is still valid
            apiGet('/auth/me')
                .then(data => {
                    setUser({ role: data.role, username: data.username });
                })
                .catch(() => {
                    // Token expired or invalid
                    localStorage.removeItem('token');
                    localStorage.removeItem('role');
                })
                .finally(() => setIsLoading(false));
        } else {
            setIsLoading(false);
        }
    }, []);

    const login = async (username, password) => {
        setError(null);
        setIsLoading(true);
        try {
            const data = await loginWithCredentials(username, password);
            localStorage.setItem('token', data.token);
            localStorage.setItem('role', data.role);
            setUser({ role: data.role, username: data.username });
            return true;
        } catch (err) {
            setError(err.message);
            return false;
        } finally {
            setIsLoading(false);
        }
    };

    const logout = () => {
        localStorage.removeItem('token');
        localStorage.removeItem('role');
        setUser(null);
    };

    return (
        <AuthContext.Provider value={{ user, login, logout, isLoading, error }}>
            {children}
        </AuthContext.Provider>
    );
};

export const useAuth = () => useContext(AuthContext);
