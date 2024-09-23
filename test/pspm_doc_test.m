classdef pspm_doc_test < matlab.unittest.TestCase
  % ● Description
  %   unittest class for the pspm_doc function
  % ● History
  %   2024 by Teddy
  properties(Constant)
    list_func = {'pspm_data_editor',...
      'pspm_import',...
      'pspm_combine_markerchannels',...
      'pspm_dcm',...
      'pspm_export',...
      'pspm_display',...
      'pspm_interpolate',...
      'pspm_convert_area2diameter',...
      'pspm_glm',...
      'pspm_extract_segments',...
      'pspm_ecg_editor',...
      'pspm_merge',...
      'pspm_convert_au2unit',...
      'pspm_process_illuminance',...
      'pspm_get_markerinfo',...
      'pspm_guide',...
      'pspm_rename',...
      'pspm_convert_ecg2hb',...
      'pspm_sf',...
      'pspm_review',...
      'pspm_split_sessions',...
      'pspm_convert_ecg2hb_amri',...
      'pspm_tam',...
      'pspm_trim',...
      'pspm_convert_gaze',...
      'pspm_convert_hb2hp',...
      'pspm_convert_ppg2hb',...
      'pspm_emg_pp',...
      'pspm_find_sounds',...
      'pspm_find_valid_fixations',...
      'pspm_gaze_pp',...
      'pspm_interpolate',...
      'pspm_pp',...
      'pspm_pupil_correct_eyelink',...
      'pspm_pupil_pp',...
      'pspm_remove_epochs',...
      'pspm_resp_pp',...
      'pspm_scr_pp',...
      'pspm_remove_epochs'};
  end
  methods (Test)
    function valid_input(this)
      for i = 1:length(this.list_func)
        disp(this.list_func{i});
        this.verifyEqual(pspm_doc(this.list_func{i}), 1);
        this.verifyEqual(isfile([this.list_func{i},'.md']), true);
        delete([this.list_func{i},'.md']);
      end
      this.verifyEqual(pspm_doc_gen(this.list_func), 1);
      for i = 1:length(this.list_func)
        this.verifyEqual(isfile(['src/markdown/',this.list_func{i},'.md']), true);
      end
      rmdir('src/markdown', 's');
    end
  end
end
