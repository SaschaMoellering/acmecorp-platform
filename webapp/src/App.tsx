import { Navigate, Route, Routes } from 'react-router-dom';
import AppLayout from './components/layout/AppLayout';
import Dashboard from './views/Dashboard';
import Orders from './views/Orders';
import OrderDetails from './views/OrderDetails';
import Catalog from './views/Catalog';
import OrdersManage from './views/OrdersManage';
import CatalogManage from './views/CatalogManage';
import SeedTools from './views/SeedTools';
import Analytics from './views/Analytics';
import SystemStatus from './views/SystemStatus';

function App() {
  return (
    <AppLayout>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/orders" element={<Orders />} />
        <Route path="/orders/:id" element={<OrderDetails />} />
        <Route path="/orders/manage" element={<OrdersManage />} />
        <Route path="/catalog" element={<Catalog />} />
        <Route path="/catalog/manage" element={<CatalogManage />} />
        <Route path="/tools/seed" element={<SeedTools />} />
        <Route path="/test-data" element={<Navigate to="/tools/seed" replace />} />
        <Route path="/analytics" element={<Analytics />} />
        <Route path="/system" element={<SystemStatus />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AppLayout>
  );
}

export default App;
