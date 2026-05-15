-- ─────────────────────────────────────────────
-- CHAT MODULE: trigger, indexes, RLS
-- ─────────────────────────────────────────────
-- Run this once in the Supabase SQL editor.
-- Idempotent — safe to re-run.
--
-- Assumes the `conversation` and `message` tables already exist
-- with this shape:
--
--   conversation(id, listing_id, tenant_id, landlord_id,
--                last_message, last_message_at, is_archived,
--                created_at)
--     FKs: tenant_id, landlord_id → profiles(id) ON DELETE CASCADE
--          listing_id            → listings_old(id) ON DELETE SET NULL
--     UNIQUE (listing_id, tenant_id, landlord_id)
--
--   message(id, conversation_id, sender_id, type, content, url,
--           file_name, is_read, created_at)
--     FKs: conversation_id → conversation(id) ON DELETE CASCADE
--          sender_id       → profiles(id)     ON DELETE CASCADE
--     CHECK type IN ('text','image','file')
--
-- Realtime: enable via Supabase dashboard → Database → Replication
-- → tick `message` (and optionally `conversation`).

-- 1. Indexes for inbox + unread queries ──────────────────────────
CREATE INDEX IF NOT EXISTS conversation_landlord_idx
  ON conversation(landlord_id, last_message_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS conversation_tenant_idx
  ON conversation(tenant_id, last_message_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS message_conversation_created_idx
  ON message(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS message_unread_recipient_idx
  ON message(conversation_id, is_read)
  WHERE is_read = false;

-- 2. Trigger ─ keep conversation.last_message + last_message_at
--             in sync with the latest inserted message ──────────
CREATE OR REPLACE FUNCTION conversation_touch_last_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE conversation
  SET last_message = COALESCE(
        NEW.content,
        CASE NEW.type
          WHEN 'image' THEN '[image]'
          WHEN 'file'  THEN '[file]'
          ELSE ''
        END
      ),
      last_message_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS message_touch_conversation ON message;
CREATE TRIGGER message_touch_conversation
  AFTER INSERT ON message
  FOR EACH ROW
  EXECUTE FUNCTION conversation_touch_last_message();

-- 3. RLS ──────────────────────────────────────────────────────────
ALTER TABLE conversation ENABLE ROW LEVEL SECURITY;
ALTER TABLE message ENABLE ROW LEVEL SECURITY;

-- conversation: only the two members can read.
DROP POLICY IF EXISTS conversation_select_member ON conversation;
CREATE POLICY conversation_select_member ON conversation
  FOR SELECT
  USING (auth.uid() = landlord_id OR auth.uid() = tenant_id);

-- conversation: either side can create the thread, must be a member.
DROP POLICY IF EXISTS conversation_insert_member ON conversation;
CREATE POLICY conversation_insert_member ON conversation
  FOR INSERT
  WITH CHECK (auth.uid() = landlord_id OR auth.uid() = tenant_id);

-- conversation: members can update (archive flag, etc).
DROP POLICY IF EXISTS conversation_update_member ON conversation;
CREATE POLICY conversation_update_member ON conversation
  FOR UPDATE
  USING (auth.uid() = landlord_id OR auth.uid() = tenant_id)
  WITH CHECK (auth.uid() = landlord_id OR auth.uid() = tenant_id);

-- message: a user can read messages whose conversation they're in.
DROP POLICY IF EXISTS message_select_member ON message;
CREATE POLICY message_select_member ON message
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversation c
      WHERE c.id = message.conversation_id
        AND (c.landlord_id = auth.uid() OR c.tenant_id = auth.uid())
    )
  );

-- message: only the authenticated sender, into a conversation
-- they're a member of.
DROP POLICY IF EXISTS message_insert_sender ON message;
CREATE POLICY message_insert_sender ON message
  FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM conversation c
      WHERE c.id = conversation_id
        AND (c.landlord_id = auth.uid() OR c.tenant_id = auth.uid())
    )
  );

-- message: members can mark read (flip is_read).
DROP POLICY IF EXISTS message_update_recipient ON message;
CREATE POLICY message_update_recipient ON message
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM conversation c
      WHERE c.id = message.conversation_id
        AND (c.landlord_id = auth.uid() OR c.tenant_id = auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM conversation c
      WHERE c.id = message.conversation_id
        AND (c.landlord_id = auth.uid() OR c.tenant_id = auth.uid())
    )
  );

-- 4. Profiles: contract counterparty read access ─────────────────
-- Lets the chat inbox/header render the other party's name+avatar.
DROP POLICY IF EXISTS profiles_select_contract_counterparty ON profiles;
CREATE POLICY profiles_select_contract_counterparty ON profiles
  FOR SELECT
  TO authenticated
  USING (
    id IN (SELECT landlord_id FROM contract WHERE tenant_id = auth.uid())
    OR id IN (SELECT tenant_id FROM contract WHERE landlord_id = auth.uid())
  );
