import { CachedProps } from '@/utils/data';
import { LightningIcon } from '@/utils/icons';
import { Tooltip } from 'antd';
import { NodeProps } from 'reactflow';
import styled from 'styled-components';

export type CustomNodeProps<T> = NodeProps<{
  originalData: T;
  index: number;
  highlight: string[];
}>;

export const StyledNode = styled.div`
  position: relative;
  width: 220px;
  border: 1px solid #e8e2da;
  border-radius: 12px;
  overflow: hidden;
  background: #fff;
  box-shadow: 0 8px 24px rgba(103, 71, 47, 0.07);
  cursor: pointer;
  transition:
    border-color 0.15s ease,
    box-shadow 0.15s ease;

  &:before {
    content: '';
    pointer-events: none;
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 1;
    border: 2px solid transparent;
    border-radius: 12px;
    transition: border-color 0.15s ease-in-out;
  }

  &:hover,
  &:focus {
    border-color: rgba(232, 133, 51, 0.35);
    box-shadow:
      0 0 0 2px rgba(232, 133, 51, 0.1),
      0 10px 24px rgba(103, 71, 47, 0.1);

    &:before {
      border-color: var(--citrus-6);
    }
  }

  .react-flow__handle {
    border: none;
    opacity: 0;

    &-left {
      left: 0;
    }

    &-right {
      right: 0;
    }
  }
`;

export const NodeHeader = styled.div`
  position: relative;
  background-color: ${(props) => props.color || 'var(--guduu-accent-soft)'};
  font-size: 14px;
  color: var(--guduu-ink);
  padding: 10px 12px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 44px;
  border-bottom: 1px solid #eee0d4;

  &.dragHandle {
    cursor: move;
  }

  .adm-model-header {
    display: flex;
    align-items: center;
    min-width: 0;

    svg {
      margin-right: 8px;
      flex-shrink: 0;
      color: var(--guduu-accent);
    }
    + svg {
      cursor: pointer;
    }

    .ant-typography {
      width: 140px;
      color: var(--guduu-ink);
      font-weight: 600;
    }
  }
`;

export const NodeBody = styled.div`
  background-color: #fff;
  padding-bottom: 6px;
`;

export const CachedIcon = ({ originalData }: { originalData: CachedProps }) => {
  return originalData.cached ? (
    <Tooltip
      title={
        <>
          Cached
          {originalData.refreshTime
            ? `: refresh every ${originalData.refreshTime}`
            : null}
        </>
      }
      placement="top"
    >
      <LightningIcon className="cursor-pointer" />
    </Tooltip>
  ) : null;
};
