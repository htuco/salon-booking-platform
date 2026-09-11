import { createBrowserRouter, Outlet } from "react-router";
import { LandingPage } from "./pages/LandingPage";
import { HomePage } from "./pages/HomePage";
import { BookingFlow } from "./pages/BookingFlow";
import { BookingSuccess } from "./pages/BookingSuccess";
import { MyAppointments } from "./pages/MyAppointments";
import { ClientLogin } from "./pages/ClientLogin";
import { ClientAccount } from "./pages/ClientAccount";
import { AdminLogin } from "./pages/AdminLogin";
import { AdminDashboard } from "./pages/AdminDashboard";
import { AdminAppointments } from "./pages/AdminAppointments";
import { AdminCalendar } from "./pages/AdminCalendar";
import { AdminServices } from "./pages/AdminServices";
import { AdminEmployees } from "./pages/AdminEmployees";
import { SuperAdminCreateSalon } from "./pages/SuperAdminCreateSalon";
import { DemoNavigation } from "./components/DemoNavigation";

function AppLayout() {
  return (
    <>
      <DemoNavigation />
      <Outlet />
    </>
  );
}

// Rute prate spec: docs/01-mvp-spec.md §12
export const router = createBrowserRouter([
  {
    element: <AppLayout />,
    children: [
      { path: "/", element: <LandingPage /> },

      // Client app — jedan salon po buildu, slug samo za demo prebacivanje
      { path: "s/barber-studio-vitez", element: <HomePage theme="barber" /> },
      { path: "s/beauty-studio-travnik", element: <HomePage theme="beauty" /> },
      { path: "s/:slug/book/success", element: <BookingSuccess /> },
      { path: "s/:slug/book/:step", element: <BookingFlow /> },
      { path: "s/:slug/auth/login", element: <ClientLogin /> },
      { path: "s/:slug/account", element: <ClientAccount /> },
      { path: "s/:slug/appointments", element: <MyAppointments /> },

      // Admin app — jedna za sve salone
      { path: "admin/login", element: <AdminLogin /> },
      { path: "admin/dashboard", element: <AdminDashboard /> },
      { path: "admin/appointments", element: <AdminAppointments /> },
      { path: "admin/calendar", element: <AdminCalendar /> },
      { path: "admin/services", element: <AdminServices /> },
      { path: "admin/employees", element: <AdminEmployees /> },

      // Super admin — Flutter Web build
      { path: "super-admin/salons/new", element: <SuperAdminCreateSalon /> },
    ],
  },
]);
