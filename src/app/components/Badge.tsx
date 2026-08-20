import { HTMLAttributes, forwardRef } from 'react';
import { clsx } from 'clsx';

interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  variant?: 'default' | 'success' | 'warning' | 'danger' | 'info';
}

export const Badge = forwardRef<HTMLSpanElement, BadgeProps>(
  ({ className, variant = 'default', children, ...props }, ref) => {
    return (
      <span
        ref={ref}
        className={clsx(
          'inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium',
          {
            'bg-neutral-100 text-neutral-800': variant === 'default',
            'bg-green-100 text-green-800': variant === 'success',
            'bg-yellow-100 text-yellow-800': variant === 'warning',
            'bg-red-100 text-red-800': variant === 'danger',
            'bg-blue-100 text-blue-800': variant === 'info',
          },
          className
        )}
        {...props}
      >
        {children}
      </span>
    );
  }
);

Badge.displayName = 'Badge';
