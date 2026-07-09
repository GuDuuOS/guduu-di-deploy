import { useRouter } from 'next/router';
import { Button, Layout, Space } from 'antd';
import styled from 'styled-components';
import LogoBar from '@/components/LogoBar';
import { Path } from '@/utils/enum';
import Deploy from '@/components/deploy/Deploy';

const { Header } = Layout;

const StyledButton = styled(Button)<{ $isHighlight: boolean }>`
  min-width: 64px;
  height: 34px;
  padding: 0 12px;
  font-weight: ${(props) => (props.$isHighlight ? '600' : '500')};
  border: none;
  border-radius: 8px;
  color: ${(props) => (props.$isHighlight ? '#fff' : '#65746c')};
  background: ${(props) =>
    props.$isHighlight
      ? 'linear-gradient(135deg, #ef8938, #dc7027)'
      : 'transparent'};
  box-shadow: ${(props) =>
    props.$isHighlight ? '0 5px 14px rgba(190, 88, 24, 0.16)' : 'none'};

  &:hover,
  &:focus {
    color: ${(props) => (props.$isHighlight ? '#fff' : '#a94f17')};
    background: ${(props) =>
      props.$isHighlight
        ? 'linear-gradient(135deg, #ef8938, #dc7027)'
        : '#fff'};
  }
`;

const NavGroup = styled(Space)`
  padding: 4px;
  background: #f3f1ed;
  border: 1px solid #e8e2da;
  border-radius: 12px;
`;

const StyledHeader = styled(Header)`
  height: 58px;
  line-height: 58px;
  border-bottom: 1px solid var(--guduu-line);
  background: var(--guduu-panel);
  padding: 0 16px;
  box-shadow: 0 5px 22px rgba(104, 73, 48, 0.07);
`;

const HeaderGrid = styled.div`
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  gap: 24px;
  height: 100%;
`;

const HeaderLeft = styled.div`
  display: flex;
  align-items: center;
  min-width: 0;
`;

const HeaderRight = styled.div`
  display: flex;
  justify-content: flex-end;
  align-items: center;
`;

export default function HeaderBar() {
  const router = useRouter();
  const { pathname } = router;
  const showNav = !pathname.startsWith(Path.Onboarding);
  const isModeling = pathname.startsWith(Path.Modeling);

  return (
    <StyledHeader>
      <HeaderGrid>
        <HeaderLeft>
          <LogoBar />
        </HeaderLeft>
        {showNav && (
          <NavGroup size={[6, 0]}>
            <StyledButton
              size="small"
              $isHighlight={pathname.startsWith(Path.Home)}
              onClick={() => router.push(Path.Home)}
            >
              Home
            </StyledButton>
            <StyledButton
              size="small"
              $isHighlight={pathname.startsWith(Path.Modeling)}
              onClick={() => router.push(Path.Modeling)}
            >
              Modeling
            </StyledButton>
            <StyledButton
              size="small"
              $isHighlight={pathname.startsWith(Path.Knowledge)}
              onClick={() => router.push(Path.KnowledgeQuestionSQLPairs)}
            >
              Knowledge
            </StyledButton>
            <StyledButton
              size="small"
              $isHighlight={pathname.startsWith(Path.APIManagement)}
              onClick={() => router.push(Path.APIManagementHistory)}
            >
              API
            </StyledButton>
          </NavGroup>
        )}
        <HeaderRight>
          {isModeling && (
            <Space size={[16, 0]} className="adm-modeling-header">
              <Deploy />
            </Space>
          )}
        </HeaderRight>
      </HeaderGrid>
    </StyledHeader>
  );
}
