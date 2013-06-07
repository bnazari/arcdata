class Incidents::CasImporter
  def import_data(chapter, file)
    @chapter = chapter
    workbook = Spreadsheet.open(file)
    Incidents::CasIncident.transaction do
      import_incident_data workbook.worksheet("Incidents") do |s|
        yield s if block_given?
      end
      import_case_data workbook.worksheet("Cases") do |s|
        yield s if block_given?
      end
      link_cas_data
    end
  end

  def import_incident_data(sheet)
    (1..(sheet.last_row_index-1)).each do |row|
      break if sheet[row, 0].blank?
      id = sheet[row,1]
      incident = Incidents::CasIncident.where(cas_incident_number: id).first_or_initialize
      cols = [:dr_number, nil, :cas_name, :incident_date, nil, nil, nil, :county_name,
              :cases_with_assistance, :cases_service_only, :cases_opened, :num_clients, :cases_closed, :cases_open]

      cols.each_with_index do |col_name, idx|
        next unless col_name
        incident.send "#{col_name}=".to_sym, sheet[row, idx]
      end
      incident.last_import = Time.now
      incident.last_date_with_open_cases = Date.today if incident.cases_open > 0
      incident.save!

      if block_given?
        yield "Incident Data"
      end
    end
  end

  def import_case_data(sheet)
    (1..(sheet.last_row_index-1)).each do |row|
      break if sheet[row, 0].blank?
      incident_num = sheet[row,0]
      incident = Incidents::CasIncident.where(cas_incident_number: incident_num).first!
      case_num = sheet[row,1]
      the_case = Incidents::CasCase.where(cas_incident_id: incident, case_number: case_num).first_or_initialize
      cols = [nil, nil, :num_clients, :family_name, :case_last_updated, :case_opened, :case_is_open, :language, :narrative, :address, :city, nil, :state,
              :post_incident_plans, nil, nil, nil, nil, nil, nil, :notes]

      cols.each_with_index do |col_name, idx|
        next unless col_name
        the_case.send "#{col_name}=".to_sym, sheet[row, idx]
      end
      the_case.last_import = Time.now
      the_case.save!

      if block_given?
        yield "Case Data"
      end
    end
  end

  def link_cas_data
    Incidents::Incident.joins{cas_incident}.where{(cas_incident_number != nil) & (cas_incident.id == nil)}.each do |incident|
      cas = Incidents::CasIncident.where(cas_incident_number: incident.cas_incident_number)
      if cas
        cas.incident = incident
        cas.save!
      end
      if block_given?
        yield "Incident Link"
      end
    end
  end
end