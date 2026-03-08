import { useState, useCallback } from 'react';

let toastId = 0;
let globalAddToast = null;

export const toast = {
    success: (message) => globalAddToast?.({ type: 'success', message }),
    error: (message) => globalAddToast?.({ type: 'error', message }),
    info: (message) => globalAddToast?.({ type: 'info', message }),
    warning: (message) => globalAddToast?.({ type: 'warning', message }),
};

const ToastContainer = () => {
    const [toasts, setToasts] = useState([]);

    const addToast = useCallback(({ type, message }) => {
        const id = ++toastId;
        setToasts(prev => [...prev, { id, type, message }]);
        setTimeout(() => {
            setToasts(prev => prev.filter(t => t.id !== id));
        }, 4000);
    }, []);

    globalAddToast = addToast;

    const removeToast = (id) => {
        setToasts(prev => prev.filter(t => t.id !== id));
    };

    const icons = {
        success: '✅',
        error: '❌',
        info: 'ℹ️',
        warning: '⚠️',
    };

    return (
        <div className="toast-container">
            {toasts.map(t => (
                <div key={t.id} className={`toast toast-${t.type}`}>
                    <span className="toast-icon">{icons[t.type]}</span>
                    <span className="toast-message">{t.message}</span>
                    <button className="toast-close" onClick={() => removeToast(t.id)}>×</button>
                </div>
            ))}
        </div>
    );
};

export default ToastContainer;
