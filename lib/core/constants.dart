// App-wide constants

class ChutesModel {
  final String displayName;
  final String modelId;
  final bool supportsImages;

  const ChutesModel({
    required this.displayName,
    required this.modelId,
    this.supportsImages = false,
  });
}

class ApiConstants {
  // Chutes.ai (free tier) — proxied through Cloud Function
  static const chutesBaseUrl = 'https://llm.chutes.ai/v1/chat/completions';

  // All available Chutes.ai models
  static const List<ChutesModel> chutesModels = [
    ChutesModel(displayName: 'GPT-OSS 120B', modelId: 'openai/gpt-oss-120b-TEE'),
    ChutesModel(displayName: 'DeepSeek V3.2', modelId: 'deepseek-ai/DeepSeek-V3.2-TEE'),
    ChutesModel(displayName: 'Kimi K2.5', modelId: 'moonshotai/Kimi-K2.5-TEE'),
    ChutesModel(displayName: 'GLM-4.7', modelId: 'zai-org/GLM-4.7-TEE'),
    ChutesModel(displayName: 'GLM-4.6', modelId: 'zai-org/GLM-4.6-TEE'),
    ChutesModel(displayName: 'GLM-4.6V', modelId: 'zai-org/GLM-4.6V', supportsImages: true),
    ChutesModel(displayName: 'Qwen3 Coder', modelId: 'Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8-TEE'),
    ChutesModel(displayName: 'Qwen3.5 397B', modelId: 'Qwen/Qwen3.5-397B-A17B-TEE'),
    ChutesModel(displayName: 'Qwen3 235B', modelId: 'Qwen/Qwen3-235B-A22B-Instruct-2507-TEE'),
    ChutesModel(displayName: 'Qwen3 Think', modelId: 'Qwen/Qwen3-235B-A22B-Thinking-2507'),
    ChutesModel(displayName: 'Qwen3 VL', modelId: 'Qwen/Qwen3-VL-235B-A22B-Instruct', supportsImages: true),
    ChutesModel(displayName: 'Qwen2.5 VL', modelId: 'Qwen/Qwen2.5-VL-72B-Instruct-TEE', supportsImages: true),
    ChutesModel(displayName: 'Qwen3 Next', modelId: 'Qwen/Qwen3-Next-80B-A3B-Instruct'),
    ChutesModel(displayName: 'Kimi K2 Think', modelId: 'moonshotai/Kimi-K2-Thinking-TEE'),
    ChutesModel(displayName: 'Kimi K2', modelId: 'moonshotai/Kimi-K2-Instruct-0905'),
    ChutesModel(displayName: 'MiroThinker', modelId: 'miromind-ai/MiroThinker-v1.5-235B'),
    ChutesModel(displayName: 'DeepSeek V3.2 SE', modelId: 'deepseek-ai/DeepSeek-V3.2-Speciale-TEE'),
    ChutesModel(displayName: 'Hermes 4 405B', modelId: 'NousResearch/Hermes-4-405B-FP8-TEE'),
    ChutesModel(displayName: 'MiniMax M2.1', modelId: 'MiniMaxAI/MiniMax-M2.1-TEE'),
    ChutesModel(displayName: 'MiMo V2 Flash', modelId: 'XiaomiMiMo/MiMo-V2-Flash'),
    ChutesModel(displayName: 'GPT-OSS 20B', modelId: 'openai/gpt-oss-20b'),
    ChutesModel(displayName: 'Nemotron 30B', modelId: 'nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-BF16'),
    ChutesModel(displayName: 'Gemma 3 27B', modelId: 'unsloth/gemma-3-27b-it'),
  ];

  static const String defaultChutesModel = 'openai/gpt-oss-120b-TEE';

  // OpenRouter (Pro tier)
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const List<ChutesModel> proModels = [
    ChutesModel(displayName: 'Gemini 3.1 Pro', modelId: 'google/gemini-3.1-pro-preview', supportsImages: true),
    ChutesModel(displayName: 'Claude Sonnet 4.6', modelId: 'anthropic/claude-sonnet-4.6', supportsImages: true),
    ChutesModel(displayName: 'Claude Opus 4.6', modelId: 'anthropic/claude-opus-4.6', supportsImages: true),
    ChutesModel(displayName: 'GPT-5.3 Codex', modelId: 'openai/gpt-5.3-codex', supportsImages: true),
  ];

  // Z.ai endpoints (BYOK + Pro)
  static const Map<String, String> zaiEndpoints = {
    'Coding (International)': 'https://api.z.ai/api/coding/paas/v4/chat/completions',
    'Coding (China)': 'https://open.bigmodel.cn/api/coding/paas/v4/chat/completions',
    'General (International)': 'https://api.z.ai/api/paas/v4/chat/completions',
    'General (China)': 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
  };
  static const String defaultZaiEndpoint = 'Coding (International)';

  // Cloud Functions base URL — updated after Firebase init
  static String cloudFunctionsBaseUrl = '';

  static const List<String> zaiModels = [
    'glm-5',
    'glm-4.7',
    'glm-4.7-flash',
  ];

  static const String defaultFreeModel = defaultChutesModel;
  static const String defaultPaidModel = 'google/gemini-2.5-pro-preview';
}

class AppLimits {
  static const int freeMessages = 30;
  static const int proMonthlyMessages = 500;
  static const int proQuotaWarning = 450;
  static const int freeQuotaWarning = 5;
  static const int maxFileSizeMB = 5;
  static const int maxImageSizeMB = 1;
  static const int freeStorageMB = 50;
  static const int proStorageMB = 500;
}

class AppStrings {
  static const appName = 'Geepity';
  static const tagline = 'Chat with AI — free to start';
  static const privacyPolicyUrl = 'https://geepity.com/privacy';
  static const termsUrl = 'https://geepity.com/terms';

  // RevenueCat product IDs
  static const proMonthlyId = 'geepity_pro_monthly';
  static const proYearlyId = 'geepity_pro_yearly';
  static const proEntitlementId = 'pro';
}

class SupportedFileExtensions {
  static const textBased = [
    'txt', 'md', 'json', 'py', 'js', 'ts', 'dart', 'java', 'kt',
    'go', 'rs', 'cpp', 'c', 'h', 'xml', 'yaml', 'toml', 'sh',
  ];
  static const images = ['jpeg', 'jpg', 'png'];
  static const all = [...textBased, ...images, 'pdf'];
}
