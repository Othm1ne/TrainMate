import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db, region } from "./bootstrap";
import { sendToUser } from "./notify";

/** Push notification for each new chat message (unless muted/blocked). */
export const onMessageCreate = onDocumentCreated(
  { region, document: "chats/{chatId}/messages/{messageId}" },
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;
    const { chatId } = event.params;

    const chat = (await db.doc(`chats/${chatId}`).get()).data();
    if (!chat) return;
    if ((chat.blockedBy ?? []).length > 0) return;

    const members: string[] = chat.members ?? [];
    const to = members.find((u) => u !== msg.senderId);
    if (!to || (chat.mutedBy ?? []).includes(to)) return;

    const senderName = chat.memberInfo?.[msg.senderId]?.name || "New message";
    const text = String(msg.text ?? "");
    await sendToUser(to, senderName, text.length > 140 ? `${text.slice(0, 137)}…` : text,
      { type: "message", chatId });
  }
);
