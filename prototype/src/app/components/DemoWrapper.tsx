import { ReactNode } from 'react';
import { DemoNavigation } from './DemoNavigation';

interface DemoWrapperProps {
  children: ReactNode;
}

export function DemoWrapper({ children }: DemoWrapperProps) {
  return (
    <>
      {children}
      <DemoNavigation />
    </>
  );
}
