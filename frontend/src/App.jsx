import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './auth/AuthContext';
import NavBar from './components/NavBar';
import ProtectedRoute from './components/ProtectedRoute';
import ToastContainer from './components/ToastContainer';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Appointments from './pages/Appointments';
import TriageForm from './pages/TriageForm';
import DoctorNotes from './pages/DoctorNotes';
import PatientHistory from './pages/PatientHistory';
import WaitingRoom from './pages/WaitingRoom';

function App() {
  const { user, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="loading-screen">
        <div className="spinner"></div>
        <p>Yükleniyor...</p>
      </div>
    );
  }

  return (
    <>
      <NavBar />
      <div className="container">
        <Routes>
          <Route path="/login" element={user ? <Navigate to="/" /> : <Login />} />
          <Route path="/waiting-room" element={<WaitingRoom />} />
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Dashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/appointments"
            element={
              <ProtectedRoute>
                <Appointments />
              </ProtectedRoute>
            }
          />
          <Route
            path="/triage/:appointmentId"
            element={
              <ProtectedRoute allowedRoles={['NURSE']}>
                <TriageForm />
              </ProtectedRoute>
            }
          />
          <Route
            path="/doctor-note/:appointmentId"
            element={
              <ProtectedRoute allowedRoles={['DOCTOR']}>
                <DoctorNotes />
              </ProtectedRoute>
            }
          />
          <Route
            path="/patient-history"
            element={
              <ProtectedRoute>
                <PatientHistory />
              </ProtectedRoute>
            }
          />
          <Route path="*" element={<Navigate to="/" />} />
        </Routes>
      </div>
      <ToastContainer />
    </>
  );
}

export default App;
