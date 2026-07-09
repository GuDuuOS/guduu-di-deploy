import Image from 'next/image';
import { BRANDING } from '@/config/branding';

interface Props {
  size?: number;
  color?: string;
}

export const Logo = (props: Props) => {
  const { size = 30 } = props;
  const height = Math.round(size * 1.36);

  return (
    <Image
      src={BRANDING.logoPath}
      alt={BRANDING.logoAlt}
      width={size}
      height={height}
      style={{ width: size, height: 'auto' }}
    />
  );
};
