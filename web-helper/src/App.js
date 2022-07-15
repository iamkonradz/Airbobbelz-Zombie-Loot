import React, { useState, useEffect } from "react";
import {
  Tooltip,
  Col,
  Row,
  Typography,
  Card,
  Form,
  Input,
  InputNumber,
  Button,
  Modal,
  Divider,
} from "antd";
import { QuestionCircleOutlined } from "@ant-design/icons";
import "antd/dist/antd.css";
import "./App.css";
import { serialize, deserialize } from "./util";

function Item({ item, chance, more, moreChance, onChange, onDelete }) {
  const [form] = Form.useForm();
  const myItem = {
    item,
    chance,
    more,
    moreChance,
  };

  return (
    <React.Fragment>
      <Form
        form={form}
        layout="inline"
        // labelCol={{ span: 24 }}
        // wrapperCol={{ span: 24 }}
        initialValues={myItem}
        onValuesChange={(values, all) => {
          // console.log("values changed", all);
          onChange(all);
        }}
      >
        <Row gutter={{ xs: 8, sm: 8, md: 16, lg: 16 }}>
          <Col span={9}>
            <Form.Item name="item" noStyle>
              {item}
            </Form.Item>
          </Col>
          <Col span={4}>
            <Form.Item name="chance" noStyle>
              <InputNumber
                min={0.001}
                max={100}
                type="text"
                value={chance}
                precision={3}
                step={0.5}
                placeholder="Chance"
                addonBefore={
                  <Tooltip title="Chance percentage for this item to drop in zombie loot between 0 and 100%, can be decimal">
                    <QuestionCircleOutlined />
                  </Tooltip>
                }
              />
            </Form.Item>
          </Col>
          <Col span={4}>
            <Form.Item name="more" noStyle>
              <InputNumber
                width="100%"
                min={0}
                max={100}
                type="text"
                value={more}
                placeholder="More"
                addonBefore={
                  <Tooltip title="This many additional rolls will be made when the parent item is added to loot. Use this for items that should drop more than one, like Money or Cigarettes">
                    <QuestionCircleOutlined />
                  </Tooltip>
                }
              />
            </Form.Item>
          </Col>
          <Col span={4}>
            <Form.Item name="moreChance" noStyle>
              <InputNumber
                min={0}
                max={100}
                type="text"
                value={moreChance}
                placeholder="More Chance"
                precision={2}
                addonBefore={
                  <Tooltip title="Chance for an item drop for each 'additional' roll. Defaults to 50% if omitted">
                    <QuestionCircleOutlined />
                  </Tooltip>
                }
              />
            </Form.Item>
          </Col>
          <Col span={3}>
            <Button onClick={onDelete} type="primary" danger>
              &times;
            </Button>
          </Col>
        </Row>
      </Form>
      <br />
    </React.Fragment>
  );
}

function AddModal({ visible, onSubmit, onClose }) {
  const [inputValue, setInputValue] = useState("");
  return (
    <Modal
      visible={visible}
      onCancel={() => {
        onClose();
      }}
      onOk={() => {
        onSubmit(inputValue);
        setInputValue("");
      }}
    >
      <br />
      <form
        onSubmit={(e) => {
          e.preventDefault();
          onSubmit(inputValue);
        }}
      >
        <Input
          addonBefore={
            <Tooltip title="Item name, 'Base.' can be omitted if the item is in base category. Case-sensitive and must match the item ID in PZ.">
              <QuestionCircleOutlined />
            </Tooltip>
          }
          type="text"
          value={inputValue}
          placeholder="Enter item name, for example `Axe` or `Radio.WalkieTalkie4`"
          onChange={(e) => setInputValue(e.target.value)}
        />
      </form>
    </Modal>
  );
}

function App() {
  const [sandboxString, setSandboxString] = useState("");
  const [items, setItems] = useState(deserialize(sandboxString));
  const [addModalVisible, setAddModalVisible] = useState(false);

  useEffect(() => {
    const searchParams = new URLSearchParams(window.location.search);
    if (searchParams.get("q")) {
      setSandboxString(searchParams.get("q"));
    }
  }, []);

  useEffect(() => {
    const serialized = serialize(items);
    if (sandboxString !== serialized) {
      setSandboxString(serialized);
    }
  }, [items]);

  return (
    <div className="App">
      <Typography.Title level={1}>Airbobbelz Loot Helper</Typography.Title>

      <Card title="Extra items value from sandbox vars">
        <Input.TextArea
          placeholder="String to put into sandbox vars 'Extra' loot. Paste your previous settings here to update them below, or start adding below to create a new setting."
          value={sandboxString}
          onChange={(ev) => setSandboxString(ev.target.value)}
          onBlur={(ev) => {
            setItems(deserialize(sandboxString));
          }}
          autoSize={{ minRows: 2, maxRows: 10 }}
          spellCheck={false}
        ></Input.TextArea>
      </Card>

      <Divider />

      <Card title="Customize Items">
        {Object.entries(items).map(([index, item]) => {
          if (item) {
            return (
              <Item
                key={`${index}:${item.item}`}
                {...item}
                onChange={(newItem) => {
                  const newItems = { ...items };
                  newItems[index] = newItem;
                  setItems(newItems);
                }}
                onDelete={() => {
                  const newItems = {
                    ...items,
                  };
                  newItems[index] = null;
                  setItems(newItems);
                }}
              />
            );
          }
        })}
        <br />
        <Button
          type="primary"
          onClick={() => {
            setAddModalVisible(true);
          }}
        >
          Add Another Item
        </Button>
      </Card>
      <AddModal
        visible={addModalVisible}
        onClose={() => {
          setAddModalVisible(false);
        }}
        onSubmit={(itemName) => {
          setAddModalVisible(false);
          const newItems = { ...items };
          newItems[Object.keys(items).length] = { item: itemName, chance: 1 };
          setItems(newItems);
        }}
      />
    </div>
  );
}

export default App;
