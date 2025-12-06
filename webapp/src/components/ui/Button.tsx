import { ButtonHTMLAttributes } from 'react';
import './button.css';

type Props = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'ghost';
};

function Button({ variant = 'primary', children, ...rest }: Props) {
  return (
    <button className={`btn btn-${variant}`} {...rest}>
      {children}
    </button>
  );
}

export default Button;
