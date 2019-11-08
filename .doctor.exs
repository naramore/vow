%Doctor.Config{
  ignore_modules: [
    Vow.Utils,
    StreamDataUtils.Function
  ],
  ignore_paths: [
    ~r/test\/support/
  ],
  min_module_doc_coverage: 40,
  min_module_spec_coverage: 0,
  min_overall_doc_coverage: 50,
  min_overall_spec_coverage: 0,
  moduledoc_required: true,
  reporter: Doctor.Reporters.Full
}
