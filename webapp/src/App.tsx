import { Navigate, Route, Routes } from 'react-router-dom';
import AppLayout from './components/layout/AppLayout';
import Dashboard from './views/Dashboard';
import Orders from './views/Orders';
import OrderDetails from './views/OrderDetails';
import Catalog from './views/Catalog';
import Analytics from './views/Analytics';
import SystemStatus from './views/SystemStatus';

function App() {
  return (
    <AppLayout>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/orders" element={<Orders />} />
        <Route path="/orders/:id" element={<OrderDetails />} />
        <Route path="/catalog" element={<Catalog />} />
        <Route path="/analytics" element={<Analytics />} />
        <Route path="/system" element={<SystemStatus />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AppLayout>
  );
}

export default App;
