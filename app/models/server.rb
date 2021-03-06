class Server < ActiveRecord::Base
  attr_accessible :name, :status, :url

  validates :name, presence: true, length: { minimum: 3, maximum: 25 }
  validates :url, presence: true, 
            format: { :with => /^(http|https):\/\/([a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}|(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}|localhost)(:[0-9]{1,5})?(\/.*)?$/ix }

  after_create :update_status

  belongs_to :user
  has_many :contacts_server
  has_many :contacts,:through => :contacts_server


  def update_status
    link_status = LinkStatus.new full_uri
    update_attribute(:status, interpreat_status(link_status.status))
    touch(:updated_at)
  end

  def self.update_statuses
    all.each do |server|
      server.update_status
      Server.server_notification_mail(server)
      @serverhistory = ServerHistory.new(server_id:server.id, status:server.status)
      @serverhistory.save
    end
  end

  def full_uri
    url
  end

  def interpreat_status(code)
    if ((200..206).to_a + (300..307).to_a).include?(code)
      "up"
    elsif ((400..417).to_a + (500..505).to_a).include?(code)
      "down"
    else
      "error"
    end
  end

  def self.server_notification_mail(server)
    if ServerHistory.last_status(server.id) != "no_record"
      if server.status != ServerHistory.last_status(server.id)
        user = User.find_by_id(server.user_id)
        recipients = []
        recipients << user.email
        rec = server.contacts
        rec.each do |r|
          recipients << r.email
        end
        if server.status == "down"
          Notifier.down_email(recipients, server).deliver
        elsif server.status == "up"
          downtime = ServerHistory.downtime(server)
          Notifier.up_email(recipients, server, downtime).deliver
        else
          
        end
      end
    end
    

  end

end
