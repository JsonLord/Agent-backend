from agent import AgentContext, UserMessage
from python.helpers.api import ApiHandler, Request, Response
from python.helpers import files, dotenv
from initialize import initialize_agent
import os
import base64

class Chat(ApiHandler):
    @classmethod
    def requires_auth(cls) -> bool:
        # Require authentication for security
        return True

    @classmethod
    def requires_csrf(cls) -> bool:
        return False

    @classmethod
    def requires_api_key(cls) -> bool:
        return True

    async def process(self, input: dict, request: Request) -> dict:
        text = input.get("message") or input.get("text") or ""
        ctxid = input.get("context")
        profile = input.get("profile")
        file_data = input.get("file")
        file_name = input.get("file_name", "uploaded_file")

        # Sanitize file name to prevent path traversal
        file_name = os.path.basename(file_name)

        dotenv.load_dotenv()
        context = self.get_context(ctxid)
        config = initialize_agent()

        if config.chat_model.provider == "Other OpenAI compatible":
            config.chat_model.provider = "other"
        if config.utility_model.provider == "Other OpenAI compatible":
            config.utility_model.provider = "other"

        if profile:
            config.profile = profile
            if profile not in config.knowledge_subdirs:
                config.knowledge_subdirs.append(profile)

        context.config = config
        curr_agent = context.agent0
        while curr_agent:
            curr_agent.config = config
            curr_agent = curr_agent.data.get(curr_agent.DATA_NAME_SUBORDINATE)

        attachment_paths = []
        if file_data:
            knowledge_dir = files.get_abs_path("knowledge/custom")
            os.makedirs(knowledge_dir, exist_ok=True)
            save_path = os.path.join(knowledge_dir, file_name)

            try:
                if isinstance(file_data, str) and "," in file_data:
                    header, encoded = file_data.split(",", 1)
                    file_data = encoded

                decoded_data = base64.b64decode(file_data)
                with open(save_path, "wb") as f:
                    f.write(decoded_data)
            except Exception:
                with open(save_path, "w") as f:
                    f.write(str(file_data))

            attachment_paths.append(save_path)

        msg = UserMessage(text, attachment_paths)
        task = context.communicate(msg)
        result = await task.result()

        return {"message": result, "context": context.id}
