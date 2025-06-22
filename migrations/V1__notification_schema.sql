-- =============================================================================
-- Diagnyx Notification Database Schema
-- Migration: V1__notification_schema.sql
-- =============================================================================

-- Create update_updated_at_column function if it doesn't exist
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 1. Email Templates Table
CREATE TABLE public.email_templates (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  template_type TEXT NOT NULL,
  template_name TEXT NOT NULL,
  subject_template TEXT NOT NULL,
  body_template TEXT NOT NULL,
  template_version INTEGER NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- 2. Email Queue Table
CREATE TABLE public.email_queue (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  alert_trigger_id UUID,
  recipient_email TEXT NOT NULL,
  template_id UUID NOT NULL,
  subject TEXT NOT NULL,
  body_html TEXT NOT NULL,
  body_text TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'delivered', 'bounced', 'failed')),
  priority INTEGER NOT NULL DEFAULT 5,
  scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  retry_count INTEGER NOT NULL DEFAULT 0,
  max_retries INTEGER NOT NULL DEFAULT 3,
  error_message TEXT,
  sent_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- 3. Email Preferences Table
CREATE TABLE public.email_preferences (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  email TEXT NOT NULL,
  frequency TEXT NOT NULL DEFAULT 'immediate' CHECK (frequency IN ('immediate', '5min', '15min', 'hourly')),
  format TEXT NOT NULL DEFAULT 'html' CHECK (format IN ('html', 'plain', 'mobile')),
  severity_filter TEXT NOT NULL DEFAULT 'high-critical' CHECK (severity_filter IN ('critical', 'high-critical', 'all')),
  quiet_hours_enabled BOOLEAN NOT NULL DEFAULT false,
  quiet_hours_start TIME NOT NULL DEFAULT '22:00',
  quiet_hours_end TIME NOT NULL DEFAULT '08:00',
  timezone TEXT NOT NULL DEFAULT 'UTC',
  is_verified BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  unsubscribe_token TEXT DEFAULT gen_random_uuid(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create triggers for updated_at columns
CREATE TRIGGER update_email_templates_updated_at
  BEFORE UPDATE ON public.email_templates
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_email_queue_updated_at
  BEFORE UPDATE ON public.email_queue
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_email_preferences_updated_at
  BEFORE UPDATE ON public.email_preferences
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Email queue function
CREATE OR REPLACE FUNCTION public.queue_alert_email(
  p_alert_trigger_id uuid, 
  p_recipient_email text, 
  p_template_type text DEFAULT 'alert_triggered'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_template_id uuid;
  v_subject text;
  v_body_html text;
  v_body_text text;
  v_email_id uuid;
BEGIN
  -- Get template
  SELECT id, subject_template, body_template 
  INTO v_template_id, v_subject, v_body_html
  FROM public.email_templates
  WHERE template_type = p_template_type
  AND is_active = true
  ORDER BY template_version DESC
  LIMIT 1;
  
  IF v_template_id IS NULL THEN
    RAISE EXCEPTION 'No active template found for type %', p_template_type;
  END IF;
  
  -- Simple plain text version
  v_body_text := regexp_replace(v_body_html, '<[^>]*>', '', 'g');
  
  -- Queue email
  INSERT INTO public.email_queue (
    alert_trigger_id,
    recipient_email,
    template_id,
    subject,
    body_html,
    body_text,
    status,
    priority,
    scheduled_at
  ) VALUES (
    p_alert_trigger_id,
    p_recipient_email,
    v_template_id,
    v_subject,
    v_body_html,
    v_body_text,
    'pending',
    CASE WHEN p_template_type = 'alert_triggered' THEN 1 ELSE 5 END,
    now()
  ) RETURNING id INTO v_email_id;
  
  RETURN v_email_id;
END;
$$;

-- Create indexes for better performance
CREATE INDEX idx_email_templates_template_type ON public.email_templates(template_type);
CREATE INDEX idx_email_templates_is_active ON public.email_templates(is_active);
CREATE INDEX idx_email_queue_status ON public.email_queue(status);
CREATE INDEX idx_email_queue_scheduled_at ON public.email_queue(scheduled_at);
CREATE INDEX idx_email_queue_priority ON public.email_queue(priority);
CREATE INDEX idx_email_preferences_user_id ON public.email_preferences(user_id);
CREATE INDEX idx_email_preferences_email ON public.email_preferences(email);
CREATE INDEX idx_email_preferences_is_active ON public.email_preferences(is_active); 