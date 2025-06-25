-- Email Notification Schema

-- Email queue table for outgoing emails
CREATE TABLE IF NOT EXISTS email_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipient_email VARCHAR(255) NOT NULL,
  subject VARCHAR(255) NOT NULL,
  body_html TEXT NOT NULL,
  body_text TEXT,
  template_id VARCHAR(100) NOT NULL,
  status VARCHAR(20) DEFAULT 'pending',
  priority INTEGER DEFAULT 3,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  sent_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  alert_trigger_id UUID,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Table to track delivery status and events
CREATE TABLE IF NOT EXISTS email_delivery_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email_queue_id UUID NOT NULL REFERENCES email_queue(id),
  delivery_status VARCHAR(20) NOT NULL,
  event_timestamp TIMESTAMP WITH TIME ZONE DEFAULT now(),
  provider_message_id VARCHAR(255),
  provider_response JSONB,
  error_message TEXT,
  bounce_reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- User email preferences
CREATE TABLE IF NOT EXISTS email_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL,
  email VARCHAR(255) NOT NULL,
  format VARCHAR(20) DEFAULT 'html',
  frequency VARCHAR(20) DEFAULT 'immediate',
  is_active BOOLEAN DEFAULT true,
  is_verified BOOLEAN DEFAULT false,
  quiet_hours_enabled BOOLEAN DEFAULT false,
  quiet_hours_start TIME DEFAULT '22:00:00',
  quiet_hours_end TIME DEFAULT '08:00:00',
  severity_filter VARCHAR(20) DEFAULT 'all',
  timezone VARCHAR(50) DEFAULT 'UTC',
  unsubscribe_token UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT unique_user_email UNIQUE (user_id, email)
);

-- Email templates
CREATE TABLE IF NOT EXISTS email_templates (
  id VARCHAR(100) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  subject_template VARCHAR(255) NOT NULL,
  body_html_template TEXT NOT NULL,
  body_text_template TEXT,
  category VARCHAR(50),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add indexes for performance
CREATE INDEX idx_email_queue_status ON email_queue(status);
CREATE INDEX idx_email_queue_scheduled ON email_queue(scheduled_at);
CREATE INDEX idx_email_delivery_log_queue_id ON email_delivery_log(email_queue_id);
CREATE INDEX idx_email_preferences_user_id ON email_preferences(user_id);
CREATE INDEX idx_email_templates_category ON email_templates(category);

-- Insert default email templates
INSERT INTO email_templates (id, name, subject_template, body_html_template, body_text_template, category)
VALUES 
('alert-notification', 'Alert Notification', 
 'Alert: {{alertName}} - {{status}}', 
 '<html><body><h1>Alert: {{alertName}}</h1><p>Status: {{status}}</p><p>Triggered at: {{triggeredAt}}</p><p>Details: {{details}}</p></body></html>', 
 'Alert: {{alertName}}\nStatus: {{status}}\nTriggered at: {{triggeredAt}}\nDetails: {{details}}',
 'alerts'
),
('welcome-email', 'Welcome Email', 
 'Welcome to Diagnyx', 
 '<html><body><h1>Welcome to Diagnyx!</h1><p>Thank you for signing up.</p></body></html>', 
 'Welcome to Diagnyx!\nThank you for signing up.',
 'onboarding'
)
ON CONFLICT (id) DO NOTHING; 