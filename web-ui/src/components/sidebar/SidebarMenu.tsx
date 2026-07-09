import React from 'react';
import styled from 'styled-components';
import { Menu, MenuProps } from 'antd';

const StyledMenu = styled(Menu)`
  &.ant-menu {
    background-color: transparent;
    border-right: 0;
    color: var(--guduu-ink);

    &:not(.ant-menu-horizontal) {
      .ant-menu-item-selected {
        color: var(--citrus-6);
        background-color: var(--guduu-accent-muted);
      }
    }

    .ant-menu-item-group {
      margin-top: 20px;

      &:first-child {
        margin-top: 0;
      }
    }

    .ant-menu-item-group-title {
      font-size: 12px;
      font-weight: 700;
      padding: 5px 16px;
    }

    .ant-menu-item {
      line-height: 28px;
      height: auto;
      margin: 0;
      font-weight: 500;

      &:not(last-child) {
        margin-bottom: 0;
      }

      &:not(.ant-menu-item-disabled):hover {
        color: var(--guduu-accent);
        background-color: var(--guduu-accent-muted);
      }

      &:not(.ant-menu-item-disabled):active {
        background-color: #ecd7c5;
      }

      &:active {
        background-color: transparent;
      }

      &-selected {
        color: var(--citrus-6);

        &:after {
          display: none;
        }

        &:hover {
          color: var(--citrus-6);
        }
      }
    }
  }
`;

export default function SidebarMenu({
  items,
  selectedKeys,
  onSelect,
}: MenuProps) {
  return (
    <StyledMenu
      mode="inline"
      items={items}
      selectedKeys={selectedKeys}
      onSelect={onSelect}
    />
  );
}
