import { Card, Typography } from "antd";
import { SoundOutlined } from "@ant-design/icons";

export function PostAudio({ src }: { src?: string | null }) {
  if (!src) return null;
  return (
    <Card size="small" style={{ marginBottom: 18 }}>
      <Typography.Text strong>
        <SoundOutlined style={{ marginRight: 6 }} />
        早报音频
      </Typography.Text>
      <audio controls src={src} style={{ display: "block", width: "100%", marginTop: 10 }} />
    </Card>
  );
}
