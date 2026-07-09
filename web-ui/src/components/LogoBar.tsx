import Image from 'next/image';
import styled from 'styled-components';
import { BRANDING } from '@/config/branding';

const BrandWrap = styled.div`
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
  white-space: nowrap;
`;

const BrandText = styled.div`
  display: inline-flex;
  align-items: baseline;
  gap: 7px;
  line-height: 1.2;
  letter-spacing: -0.02em;
`;

const BrandName = styled.span`
  color: var(--guduu-ink);
  font-size: 14px;
  font-weight: 600;
`;

const BrandTagline = styled.span`
  color: var(--guduu-accent);
  font-size: 14px;
  font-weight: 600;
`;

export default function LogoBar() {
  return (
    <BrandWrap>
      <Image
        src={BRANDING.logoPath}
        alt={BRANDING.logoAlt}
        width={28}
        height={38}
        style={{ width: 28, height: 'auto' }}
      />
      <BrandText>
        <BrandName>{BRANDING.name}</BrandName>
        <BrandTagline>{BRANDING.tagline}</BrandTagline>
      </BrandText>
    </BrandWrap>
  );
}
