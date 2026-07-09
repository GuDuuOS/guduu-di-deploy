import { useEffect } from 'react';
import { Button, Space, Typography, message } from 'antd';
import CheckCircleOutlined from '@ant-design/icons/CheckCircleOutlined';
import LoadingOutlined from '@ant-design/icons/LoadingOutlined';
import WarningOutlined from '@ant-design/icons/WarningOutlined';
import styled from 'styled-components';
import { SyncStatus } from '@/apollo/client/graphql/__types__';
import { useDeployMutation } from '@/apollo/client/graphql/deploy.generated';
import { useDeployStatusContext } from '@/components/deploy/Context';

const { Text } = Typography;

const StatusText = styled(Text)`
  color: var(--guduu-muted) !important;
  font-size: 12px;
`;

const DeployButton = styled(Button)`
  min-width: 88px;
  height: 34px;
  border-radius: 6px;
  font-weight: 600;

  &:not(:disabled) {
    color: #fff !important;
    background: var(--guduu-accent) !important;
    border-color: var(--guduu-accent) !important;
    box-shadow: 0 4px 12px rgba(184, 91, 24, 0.14);
  }

  &:disabled {
    color: var(--guduu-muted) !important;
    background: #fffdf9 !important;
    border-color: var(--guduu-line) !important;
  }
`;

const getDeployStatus = (deploying: boolean, status: SyncStatus) => {
  const syncStatus = deploying ? SyncStatus.IN_PROGRESS : status;

  return (
    {
      [SyncStatus.IN_PROGRESS]: (
        <Space size={[4, 0]}>
          <LoadingOutlined
            className="mr-1"
            style={{ color: 'var(--guduu-accent)' }}
          />
          <StatusText>Deploying...</StatusText>
        </Space>
      ),
      [SyncStatus.SYNCRONIZED]: (
        <Space size={[4, 0]}>
          <CheckCircleOutlined className="mr-1" style={{ color: '#5db477' }} />
          <StatusText>Synced</StatusText>
        </Space>
      ),
      [SyncStatus.UNSYNCRONIZED]: (
        <Space size={[4, 0]}>
          <WarningOutlined className="mr-1" style={{ color: '#d97706' }} />
          <StatusText>Undeployed changes</StatusText>
        </Space>
      ),
    }[syncStatus] || ''
  );
};

export default function Deploy() {
  const deployContext = useDeployStatusContext();
  const { data, loading, startPolling, stopPolling } = deployContext;

  const [deployMutation, { data: deployResult, loading: deploying }] =
    useDeployMutation({
      onError: (error) => console.error(error),
      onCompleted: (data) => {
        if (data.deploy?.status === 'FAILED') {
          console.error('Failed to deploy - ', data.deploy?.error);
          message.error(
            'Failed to deploy. Please check the log for more details.',
          );
        }
      },
    });

  useEffect(() => {
    // Stop polling deploy status if deploy failed
    if (
      deployResult?.deploy?.status === 'FAILED' &&
      data?.modelSync.status === SyncStatus.UNSYNCRONIZED
    ) {
      stopPolling();
    }
  }, [deployResult, data]);

  const syncStatus = data?.modelSync.status;

  const onDeploy = () => {
    deployMutation();
    startPolling(1000);
  };

  useEffect(() => {
    if (syncStatus === SyncStatus.SYNCRONIZED) stopPolling();
  }, [syncStatus]);

  const disabled =
    deploying ||
    loading ||
    [SyncStatus.SYNCRONIZED, SyncStatus.IN_PROGRESS].includes(syncStatus);

  return (
    <Space size={[8, 0]}>
      {getDeployStatus(deploying, syncStatus)}
      <DeployButton
        disabled={disabled}
        onClick={() => onDeploy()}
        size="small"
        data-guideid="deploy-model"
      >
        Deploy
      </DeployButton>
    </Space>
  );
}
